# modules/eks

A private EKS cluster with managed node groups, built for a VPC with no internet egress.

It goes into private subnets that reach AWS through interface endpoints, like the ones `modules/vpc` creates. It opens the endpoints SG to the cluster SG itself, so nodes can bootstrap.

## Reusable

- It takes subnet IDs and an endpoints SG ID, not a VPC module, so any zero-egress VPC with private subnets and endpoints works.
- Node groups are a map. One entry is one node group, so going from one group to several is a tfvars change, not a module edit.
- Sizing, Kubernetes version, AMI and logging are all inputs.
- The region comes from the caller's provider, so there's no region input to get wrong.
- Required inputs are the things a caller has to decide. Everything else has a sensible default.
- Admin access and the public endpoint are optional, switched by inputs.
- Bootstrap admin is off, so the result is the same whether a person or a CI role runs `apply`.

It's built for **zero-egress environments** on purpose. It assumes the VPC has no internet route and reaches AWS only through VPC endpoints, and it always wires the cluster into those endpoints. It isn't meant for NAT-based VPCs.

## Design decisions

**Node groups as a map.**
Why: real clusters usually need more than one group (a small system group, an app group, later Spot or ARM). With `for_each` over a map, the number of groups comes from tfvars, and the module code stays the same for everyone.
Trade-off: callers have to pick a key for each group. The key is part of the group's name and identity, so renaming it replaces the group.

**Region in the IAM role names.**
Why: IAM is global to the account. Without the region in the name, deploying the same `project_name` in a second region fails with `EntityAlreadyExists`. The region is read from the provider with `data "aws_region"`, so it always matches where the cluster actually is.

**Private API endpoint always on. Public only when `admin_cidrs` is set.**
Why: nodes always talk to the control plane privately. The public endpoint is opt-in and limited to specific IPs, so the default is private only.

**Bootstrap creator admin off, admin granted explicitly.**
Why: with bootstrap on, whoever runs the first `apply` silently becomes admin, which differs between a laptop and CI. If the declared admin is the same identity, the two entries collide (`ResourceInUseException`). Declaring access explicitly is predictable and auditable.
Trade-off: no declared admin means no access, so `admin_principal_arn` is required in the env.

**Zero egress only. The endpoints rule is required (no `count`).**
Why: the module exists for clusters with no internet route, where nodes can only reach ECR, STS and EKS through VPC endpoints. In that setup a cluster without the rule can't join nodes, so it's never optional.

**Every node group depends on the endpoints rule.**
Why: without it, nodes can boot before they can reach ECR, STS and EKS, and fail to join. With no internet route there's no fallback.

**The log group is created before the cluster.**
Why: otherwise EKS creates its own log group with no retention, so logs pile up forever and Terraform doesn't manage it.

**`desired_size` ignored after creation.**
Why: an autoscaler or an on-call engineer will own the live count. Without the ignore, every routine `apply` would reset it and evict pods. Terraform keeps the guardrails (`min_size`, `max_size`).
Trade-off: until an autoscaler exists, resizing an existing group doesn't happen through tfvars.

**SSM policy kept on the nodes.**
Why: in a cluster with no egress, SSM Session Manager is the only way into a node that never joined. `kubectl debug` only works on nodes already in the cluster.

## Resources

| Area | What gets created |
|---|---|
| Cluster | `aws_eks_cluster` named `<project_name>-eks-cluster` |
| API endpoint | Private always on. Public only when `admin_cidrs` isn't empty, limited to those CIDRs |
| Nodes | One managed node group per `node_groups` entry, named `<project_name>-eks-node-group-<key>`, across the private subnets |
| Endpoints access | 443 ingress on the endpoints SG from the cluster SG |
| Cluster IAM | `<project_name>-<region>-eks-cluster-role` with `AmazonEKSClusterPolicy` |
| Node IAM | `<project_name>-<region>-eks-nodegroup-role` with `AmazonEKSWorkerNodePolicy`, `AmazonEKS_CNI_Policy`, `AmazonEC2ContainerRegistryReadOnly`, `AmazonSSMManagedInstanceCore` (shared by all node groups) |
| Access | Access entry + `AmazonEKSClusterAdminPolicy` (cluster scope) when `admin_principal_arn` is set |
| Logs | CloudWatch log group, created before the cluster so retention applies |

## Usage

```hcl
module "eks" {
  source = "../../modules/eks"

  project_name                = var.project_name
  private_subnet_ids          = module.vpc.private_subnet_ids
  endpoints_security_group_id = module.vpc.endpoints_sg_id
  kubernetes_version          = "<supported version>"

  node_groups = {
    main = {
      instance_type = "m5.xlarge"
      desired_size  = 9
      min_size      = 9
      max_size      = 12
    }
  }

  admin_principal_arn = "arn:aws:iam::<account-id>:user/<your-user>"
  admin_cidrs         = ["203.0.113.5/32"]

  depends_on = [module.vpc]
}
```

`depends_on` makes sure the endpoints exist before nodes try to join. To add a second group, add another entry to `node_groups` (for example `system = { ... }`).

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `project_name` | string | required | Prefix for every resource name |
| `private_subnet_ids` | list(string) | `[]` (always pass it) | Subnets for the control plane ENIs and nodes |
| `endpoints_security_group_id` | string | required | Endpoints SG the cluster needs to reach |
| `kubernetes_version` | string | required | Must be a version EKS currently offers |
| `node_groups` | map(object) | required | Group key => `instance_type`, `desired_size`, `min_size`, `max_size` |
| `nodes_ami_type` | string | `AL2023_x86_64_STANDARD` | AMI type for all node groups |
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
| `log_group_name` | CloudWatch log group name |

## Access

- Bootstrap admin is off. Access is only what you declare.
- **Bootstrap off + `admin_principal_arn = null` means nobody can reach the Kubernetes API.** Only skip the ARN if access entries are managed somewhere else.
- Use the plain IAM ARN (`arn:aws:iam::...:user/...` or `...:role/...`), not `assumed-role/...`.
- A CI role that only runs Terraform doesn't need an access entry, since everything here is AWS API.

## Scaling

- Sizes are per node group. `desired_size` is ignored after creation so an autoscaler can own it, and Terraform owns `min_size` and `max_size`.
- Changing a group's `instance_type`, or renaming its key, replaces that group, so expect a short gap with no nodes in it.
- Each group spans all private subnets and is balanced across AZs best effort, not exactly N per AZ.
- Check EC2 vCPU quotas before scaling up (9 × m5.xlarge = 36 vCPU).

## Getting into nodes

- `kubectl debug node/<name>` works through the Kubernetes API (the debug image has to be in ECR).
- SSM Session Manager works with zero egress through the SSM endpoints. It's the only way in when a node never joins, which is why the SSM policy stays on the node role.

## Current limits

Things a caller can't change without editing the module yet:

- **One admin, cluster admin only.** No multiple admins or namespace-scoped users yet. Planned: an `access_entries` map.
- **Node groups share one AMI type, one node role and the same subnets.** Per-group AMI, subnets and labels can be added to the `node_groups` object later.
- **The same `project_name` in the same region and account collides.** Give each environment its own `project_name`.
- **No CA data or OIDC issuer outputs.** These are needed for the `helm`/`kubernetes` providers and for IRSA.
- **No managed add-ons.** VPC CNI, CoreDNS and kube-proxy run at whatever versions EKS installs.
- **No KMS encryption or launch template options.**
- **No input validation** (sizes, retention values, empty subnet list).

## Notes

- **Images must come from ECR.** Public registry pulls fail with `ImagePullBackOff`. The EKS add-ons pull from AWS-managed ECR, so they work.
- **The cluster SG allows all outbound**, so no egress rules are needed here.
- **Provider floor is `>= 5.40`** because of access entries.
- **tfsec:** no KMS encryption for secrets or the log group yet. The control plane logging finding is a false positive (it can't see the variable through the module call).