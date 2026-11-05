# modules/vpc

A three-tier, zero-egress VPC. There's no NAT gateway, and the private subnets have no route to the internet, so everything in them reaches AWS through VPC endpoints.

Built to host EKS, but any workload in the private subnets can use it by bringing its own security group.

## Reusable

- No provider or backend config. Region, tags and state come from the caller. The region is read from the caller's provider (`data "aws_region"`), so there's no region input to get wrong.
- Nothing hardcoded. Subnet CIDRs are computed from `vpc_cidr` with fixed offsets, so 1 to 6 AZs work without code changes, and adding an AZ never moves existing subnets.
- It doesn't know about EKS or any other workload. It creates security groups only for what it owns (the endpoints). Each workload brings its own security group and plugs into the endpoints through `endpoint_client_security_group_ids`.
- The endpoint list is an input.

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

**Security groups only for what the module owns.**
Why: the module owns the endpoints, so it creates their security group. Workloads (EKS, EC2, a database) belong to whoever deploys them, and their ports and rules differ, so they bring their own. The VPC originally shipped ALB, app and DB security groups from the EC2 design. Nothing on EKS used them, and unused permissions are a least-privilege risk if someone attaches them later, so they were removed.

**Zero egress is enforced by routing, not security groups.**
Why: the private route table has no internet route and there's no NAT. A security group that allows all outbound (like the EKS cluster's) still can't reach the internet, so bringing your own security group can't break zero egress. Only changing the network itself (adding a NAT or an internet route) could.

**The endpoints security group starts closed.**
Why: it has no rules of its own. Nothing can reach the endpoints until a consumer opens access for itself: the EKS module adds a rule for the cluster SG, and other workloads pass their SG in. Least privilege by default.

**The default security group is locked down.**
Why: every VPC gets an AWS default security group that allows all traffic between its members, and anything launched without a security group lands in it. The module takes it over with `aws_default_security_group` and no rules, so it denies everything.

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
| Public routing | Internet gateway, public route table with `0.0.0.0/0` → IGW. Reserved for load balancers |
| Private routing | Private route table with **no internet route**, only the S3 gateway route |
| DB | One route table per DB subnet (no routes), DB subnet group. No database or DB security group yet |
| Endpoints | Interface endpoints in every private subnet with private DNS, plus an S3 gateway endpoint |
| Security groups | `endpoints_sg` (closed by default), and the VPC's default security group locked to no rules |

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

- **`vpc_cidr` must be a /16.** The offsets assume it. A smaller VPC would make the tiers overlap. (Not validated in code yet.)
- **`availability_zone_count` must be 6 or fewer.** A 7th AZ would push public into the DB range. (Not validated in code yet.)
- **Adding an AZ is safe.** Removing one still deletes that AZ's subnets and everything in them.

## Security groups

| SG | Ingress | Egress |
|---|---|---|
| `endpoints_sg` | 443 from each SG in `endpoint_client_security_group_ids`, plus whatever consumers add themselves (the EKS module adds 443 from the cluster SG) | none (replies to allowed requests are stateful) |
| Default SG | none | none |

## Usage

```hcl
module "vpc" {
  source = "../../modules/vpc"

  project_name            = var.project_name
  availability_zone_count = 3
  vpc_cidr                = "10.0.0.0/16"
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `project_name` | string | required | Prefix for every resource name |
| `availability_zone_count` | number | required | Number of AZs to spread across (1–6) |
| `vpc_cidr` | string | required | VPC CIDR block (a /16) |
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
- **Adding a database later:** put it in the DB subnets with the DB subnet group, in its own module that creates its security group allowing the EKS cluster SG on the database port.