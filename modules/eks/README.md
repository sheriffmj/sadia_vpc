# modules/eks

A private EKS cluster with one managed node group, built for a VPC with no internet egress.

It goes into private subnets that reach AWS through interface endpoints, like the ones `modules/vpc` creates. It opens the endpoints SG to the cluster SG itself, so nodes can bootstrap.

## Reusable

- It takes subnet IDs and an endpoints SG ID, not a VPC module, so any VPC with private subnets and endpoints works.
- Sizing, Kubernetes version, AMI and logging are all inputs. Dev went from 2 × t3.medium to 9 × m5.xlarge with a tfvars change only.
- Required inputs are the things a caller has to decide. Everything else has a sensible default.
- Admin access and the public endpoint are optional, switched by inputs.
- Bootstrap admin is off, so the result is the same whether a person or a CI role runs `apply`.
- Names come from `project_name`, so several clusters can live in one account.

## Design decisions

**Private API endpoint always on. Public only when `admin_cidrs` is set.**
Why: nodes always talk to the control plane privately. The public endpoint is opt-in and limited to specific IPs, so the default is private only.

**Bootstrap creator admin off, admin granted explicitly.**
Why: with bootstrap on, whoever runs the first `apply` silently becomes admin, which differs between a laptop and CI. If the declared admin is the same identity, the two entries collide (`ResourceInUseException`). Declaring access explicitly is predictable and auditable.
Trade-off: no declared admin means no access, so `admin_principal_arn` is required in the env.

**Admin access optional in the module (`count` on a null ARN).**
Why: some callers manage access entries elsewhere (SSO mappings, a separate access module). The module shouldn't force an ARN on them. The env is strict, the module is flexible.

**The endpoints rule is required (no `count`).**
Why: nodes can't join without it, so making it optional would only create a broken cluster. The old `count` also depended on a value unknown until apply, which can fail the first plan.

**The node group depends on the endpoints rule.**
Why: without it, nodes can boot before they can reach ECR, STS and EKS, and fail to join. With no internet route there's no fallback.

**The log group is created before the cluster.**
Why: otherwise EKS creates its own log group with no retention, so logs pile up forever and Terraform doesn't manage it.

**`desired_size` ignored after creation.**
Why: an autoscaler or an on-call engineer will own the live count. Without the ignore, every routine `apply` would reset it and evict pods. Terraform keeps the guardrails (`min_size`, `max_size`).
Trade-off: until an autoscaler exists, resizing an existing group doesn't happen through tfvars.

**SSM policy kept on the nodes.**
Why: in a cluster with no egress, SSM Session Manager is the only way into a node that never joined. `kubectl debug` only works on nodes already in the cluster.

**Required inputs vs defaults.**
Why: anything a caller has to decide (version, sizing, subnets, endpoints SG) has no default, so it can't be forgotten. Things that rarely change (AL2023, log types, retention, auth mode) have defaults, so the module is easy to call.

## Resources

| Area | What gets created |
|---|---|
| Cluster | `aws_eks_cluster` named `<project_name>-eks-cluster` |
| API endpoint | Private always on. Public only when `admin_cidrs` isn't empty, limited to those CIDRs |
| Nodes | One managed node group across the private subnets |
| Endpoints access | 443 ingress on the endpoints SG from the cluster SG |
| Cluster IAM | Role with `AmazonEKSClusterPolicy` |
| Node IAM | Role with `AmazonEKSWorkerNodePolicy`, `AmazonEKS_CNI_Policy`, `AmazonEC2ContainerRegistryReadOnly`, `AmazonSSMManagedInstanceCore` |
| Access | Access entry + `AmazonEKSClusterAdminPolicy` (cluster scope) when `admin_principal_arn` is set |
| Logs | CloudWatch log group, created before the cluster so retention applies |

## Usage

```hcl
module "eks" {
  source = "../../modules/eks"

  project_name                = var.project_name
  private_subnet_ids          = module.vpc.private_subnet_ids
  endpoints_security_group_id = module.vpc.endpoints_sg_id

  kubernetes_version = "<supported version>"
  instance_type      = "m5.xlarge"
  desired_size       = 9
  min_size           = 9
  max_size           = 12

  admin_principal_arn = "arn:aws:iam::<account-id>:user/<your-user>"
  admin_cidrs         = ["203.0.113.5/32"]

  depends_on = [module.vpc]
}
```

`depends_on` makes sure the endpoints exist before nodes try to join.

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `project_name` | string | required | Prefix for every resource name |
| `private_subnet_ids` | list(string) | `[]` (always pass it) | Subnets for the control plane ENIs and nodes |
| `endpoints_security_group_id` | string | required | Endpoints SG the cluster needs to reach |
| `kubernetes_version` | string | required | Must be a version EKS currently offers |
| `desired_size` | number | required | Starting node count (ignored after creation) |
| `min_size` | number | required | Node floor |
| `max_size` | number | required | Node ceiling |
| `instance_type` | string | `t3.medium` | Node instance type |
| `nodes_ami_type` | string | `AL2023_x86_64_STANDARD` | Node AMI type |
| `admin_principal_arn` | string | `null` | IAM user/role to make cluster admin. `null` = no access entry |
| `admin_cidrs` | list(string) | `[]` | CIDRs allowed to the public API. Empty = private only |
| `auth_mode` | string | `API_AND_CONFIG_MAP` | Cluster authentication mode |
| `retention_in_days` | number | `90` | Log retention (must be a value CloudWatch accepts) |
| `enabled_cluster_log_types` | list(string) | all five | `api`, `audit`, `authenticator`, `controllerManager`, `scheduler` |

## Outputs

| Name | Description |
|---|---|
| `eks_cluster_name` | Cluster name, for `update-kubeconfig` |
| `eks_cluster_arn` | Cluster ARN |
| `eks_cluster_endpoint` | API server endpoint |
| `eks_cluster_security_group_id` | Cluster SG created by EKS |
| `eks_node_group_name` | Node group name |
| `eks_node_group_arn` | Node group ARN |
| `eks_node_role_arn` | Node IAM role ARN |
| `log_group_name` | CloudWatch log group name |

## Access

- Bootstrap admin is off. Access is only what you declare.
- **Bootstrap off + `admin_principal_arn = null` means nobody can reach the Kubernetes API.** Only skip the ARN if access entries are managed somewhere else.
- Use the plain IAM ARN (`arn:aws:iam::...:user/...` or `...:role/...`), not `assumed-role/...`.
- A CI role that only runs Terraform doesn't need an access entry, since everything here is AWS API.

## Scaling

- `desired_size` is ignored after creation so an autoscaler can own it. Terraform owns `min_size` and `max_size`.
- Changing `instance_type` replaces the node group, so expect a short gap with no nodes.
- One node group across all AZs is balanced best effort, not exactly N per AZ.
- Check EC2 vCPU quotas before scaling up (9 × m5.xlarge = 36 vCPU).

## Getting into nodes

- `kubectl debug node/<name>` works through the Kubernetes API (the debug image has to be in ECR).
- SSM Session Manager works with zero egress through the SSM endpoints. It's the only way in when a node never joins, which is why the SSM policy stays on the node role.

## Notes

- **Images must come from ECR.** Public registry pulls fail with `ImagePullBackOff`. The EKS add-ons pull from AWS-managed ECR, so they work.
- **The cluster SG allows all outbound**, so no egress rules are needed here.
- **Provider floor is `>= 5.40`** because of access entries.
- **tfsec:** no KMS encryption for secrets or the log group yet. The control plane logging finding is a false positive (it can't see the variable through the module call).