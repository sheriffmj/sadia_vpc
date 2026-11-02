# modules/vpc

A three-tier VPC with no NAT gateway. The private subnets have no route to the internet, so everything in them reaches AWS through VPC endpoints.

Built to host EKS, but anything in the private subnets works as long as its security group can reach the endpoints.

## Reusable

- No provider or backend config. Region, tags and state come from the caller.
- Nothing hardcoded. Subnet CIDRs are computed from `vpc_cidr` with fixed offsets, so 1 to 6 AZs work without code changes, and adding an AZ never moves existing subnets.
- It doesn't know about EKS. It just outputs subnet and SG IDs that anything can use.
- Other workloads plug in through `endpoint_client_security_group_ids`, and the endpoint list is an input.

## Design decisions

The first two came out of adjusting this project for EKS. It started as a classic EC2 + ALB + RDS layout, where equal /24s and AZ-count-based offsets were fine. Running Kubernetes on it changed what the network needs.

**Bigger private subnets (/20 instead of /24).**
Why: on EKS, every pod takes a VPC IP from the private subnet, and the VPC CNI keeps spare IPs on each node. With EC2 instances a /24 was plenty, but at 4 m5.xlarge nodes per AZ it's nearly full. A subnet's size can't change without replacing it, so I resized it during the EKS rework, before real workloads made it expensive.
Trade-off: the private tier uses a much bigger share of the VPC, so the layout assumes a /16.

**Fixed subnet offsets, sized for 6 AZs.**
Why: the original offsets came from the AZ count, so adding an AZ shifted every private and DB CIDR and replaced those subnets. That didn't matter much for a few EC2 instances, but on EKS those subnets hold the nodes, the control plane ENIs and the endpoint ENIs. Fixed offsets mean adding an AZ only adds subnets, which also made room for the bigger private tier without overlaps.
Trade-off: address space is reserved for AZs you may never use (cheap on a /16), and the AZ count is capped at 6.

**Endpoints instead of NAT.**
Why: no egress path means no data exfiltration route and a smaller attack surface. The S3 gateway endpoint is free and carries ECR image layers, so pulls don't cost endpoint traffic.
Trade-off: each interface endpoint is billed per AZ, and anything not covered by an endpoint is unreachable.

**Security groups reference other security groups, not CIDRs.**
Why: rules follow the resources, not IP addresses. A new instance in `app_sg` is allowed to the DB automatically, and nothing else in the VPC is, even if it shares a subnet. This is least privilege inside the VPC.

**Egress is restricted too.**
Why: most setups only lock down ingress. `app_sg` can only reach the endpoints, S3 and MySQL, so a compromised host can't reach anything else in the VPC.

**Client SGs passed as a map, not a list.**
Why: `for_each` needs its keys known at plan time. With static keys (`my_app = sg-...`), the SG can be created in the same apply, since only the value is unknown.

**The module doesn't add egress rules to SGs it doesn't own.**
Why: a module silently changing someone else's SG is surprising and hard to debug. It exports `endpoints_sg_id` and `s3_prefix_list_id` so callers write their own egress rules.

**The endpoint list is an input.**
Why: add-ons need different endpoints (load balancer controller, autoscaler, Karpenter). Callers add them without editing the module.

## Resources

| Area | What gets created |
|---|---|
| VPC | VPC with DNS support and DNS hostnames on (needed for endpoint private DNS) |
| Subnets | One public (/24), one private (/20) and one DB (/24) subnet per AZ |
| Public routing | Internet gateway, public route table with `0.0.0.0/0` → IGW |
| Private routing | Private route table with **no internet route**, only the S3 gateway route |
| DB | One route table per DB subnet (no routes), DB subnet group |
| Endpoints | Interface endpoints in every private subnet with private DNS, plus an S3 gateway endpoint |
| Security groups | `endpoints_sg`, `alb_sg`, `app_sg`, `db_sg`, using SG-to-SG rules |

Default interface endpoints: `ssm`, `ec2messages`, `ssmmessages`, `ec2`, `eks`, `ecr.api`, `ecr.dkr`, `sts`, `logs`.

## Subnet layout

Each tier has a **fixed offset** sized for up to 6 AZs (`local.max_azs = 6`), so adding an AZ only adds subnets. Existing subnets never move or get replaced.

Private subnets are bigger, because every pod takes a VPC IP from them.

```hcl
public_cidr     = cidrsubnet(var.vpc_cidr, 8, idx)                 # /24, offsets 0-5
db_private_cidr = cidrsubnet(var.vpc_cidr, 8, idx + local.max_azs) # /24, offsets 6-11
private_cidr    = cidrsubnet(var.vpc_cidr, 4, idx + 1)             # /20, blocks 1-6
```

With `10.0.0.0/16`:

| Tier | Size | AZ a | AZ b | AZ c | Reserved for 6 AZs |
|---|---|---|---|---|---|
| Public | /24 (251 IPs) | `10.0.0.0/24` | `10.0.1.0/24` | `10.0.2.0/24` | `10.0.0.0` – `10.0.5.255` |
| DB | /24 (251 IPs) | `10.0.6.0/24` | `10.0.7.0/24` | `10.0.8.0/24` | `10.0.6.0` – `10.0.11.255` |
| Private | /20 (4,091 IPs) | `10.0.16.0/20` | `10.0.32.0/20` | `10.0.48.0/20` | `10.0.16.0` – `10.0.111.255` |

How it fits:

- Public and DB /24s share the first /20 block (`10.0.0.0` – `10.0.15.255`).
- Private starts at the second /20 block. The `+ 1` skips the first block, because a /20 can only start on a multiple of 16 in the third number.
- `10.0.112.0` onward is free for later (for example a secondary pod range).

Rules:

- **`vpc_cidr` should be a /16.** The offsets assume it. A smaller VPC would make the tiers overlap.
- **`availability_zone_count` is capped at 6.** A 7th AZ would push public into the DB range.
- **Adding an AZ is safe.** Removing one still deletes that AZ's subnets and everything in them.

## Security group rules

| SG | Ingress | Egress |
|---|---|---|
| `endpoints_sg` | 443 from `app_sg` and from each client SG | (default) |
| `alb_sg` | 80/443 from `inbound_web_cidr` | 80 to `app_sg` |
| `app_sg` | 80 from `alb_sg` | 443 to `endpoints_sg`, 443 to S3 prefix list, 3306 to `db_sg` |
| `db_sg` | 3306 from `app_sg` | (default) |

## Usage

```hcl
module "vpc" {
  source = "../../modules/vpc"

  project_name            = var.project_name
  aws_region              = var.aws_region
  availability_zone_count = 3
  vpc_cidr                = "10.0.0.0/16"
  inbound_web_cidr        = ["0.0.0.0/0"]
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `project_name` | string | required | Prefix for every resource name |
| `aws_region` | string | required | Used to build endpoint service names |
| `availability_zone_count` | number | required | Number of AZs to spread across (1–6) |
| `vpc_cidr` | string | required | VPC CIDR block (a /16) |
| `inbound_web_cidr` | list(string) | required | CIDRs allowed to the ALB on 80/443 |
| `interface_endpoints_services` | list(string) | 9 services above | Service names after `com.amazonaws.<region>.` |
| `endpoint_client_security_group_ids` | map(string) | `{}` | Client name => SG ID allowed 443 to the endpoints |

## Outputs

| Name | Description |
|---|---|
| `vpc_id` | VPC ID |
| `public_subnet_ids` | Public subnet IDs |
| `private_subnet_ids` | Private subnet IDs |
| `db_private_subnet_ids` | DB subnet IDs |
| `db_subnet_group_name` | DB subnet group name |
| `alb_sg_id` | ALB security group ID |
| `app_sg_id` | App security group ID |
| `db_sg_id` | DB security group ID |
| `endpoints_sg_id` | Endpoints security group ID |
| `s3_prefix_list_id` | S3 gateway prefix list ID, for client egress rules |

## Bring your own security group

```hcl
endpoint_client_security_group_ids = {
  my_app = aws_security_group.my_app.id
}
```

It's a map with static keys so it works with SGs created in the same apply.

This only opens the endpoints side. Terraform-created SGs have no egress, so your SG also needs 443 egress to `endpoints_sg_id` and to `s3_prefix_list_id`:

```hcl
resource "aws_vpc_security_group_egress_rule" "to_endpoints" {
  security_group_id            = aws_security_group.my_app.id
  referenced_security_group_id = module.vpc.endpoints_sg_id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}

resource "aws_vpc_security_group_egress_rule" "to_s3" {
  security_group_id = aws_security_group.my_app.id
  prefix_list_id    = module.vpc.s3_prefix_list_id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}
```

Don't pass the EKS cluster SG here. The EKS module adds its own rule, and passing it here too fails with a duplicate rule error.

## Notes

- **No internet from private subnets.** Images have to come from ECR, and third-party APIs aren't reachable.
- **Cost scales with AZs.** Each interface endpoint has an ENI per AZ: 9 services × 3 AZs = 27 ENIs billed hourly.
- **Some endpoints aren't available in every AZ.** If one fails with an AZ error, that's the cause.
- **Add endpoints as add-ons need them.** `elasticloadbalancing` for the Load Balancer Controller, `autoscaling` for an autoscaler, `sqs` and `pricing` for Karpenter.
- `map_public_ip_on_launch = false` on public subnets.
- The ALB/app/DB SGs are for a classic EC2 tier and will move into `alb` and `ec2` modules.