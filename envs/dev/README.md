# envs/dev

The dev root module. Run `terraform` from here.

This folder only holds values and wiring. All the logic is in the modules, so changing dev means changing `terraform.tfvars`.

Currently: one node group, `main`, with **9 × m5.xlarge** across 3 AZs.

`aws_region` is only used by the provider. The modules read the region from the provider, so it's set in one place.

## Design decisions

**No defaults on any variable here.**
Why: this is where decisions get made. A missing value fails at plan instead of silently using something out of date.

**9 × m5.xlarge, 3 AZs, min 9 / max 12.**
Why: about 3 nodes per AZ, so losing a node costs 1/9 of capacity, not 1/3. m5.xlarge raises the pod and CPU ceiling over smaller instances, so the cluster can absorb an AZ outage. Min 9 keeps that headroom from being scaled away, and max 12 leaves room in multiples of 3.

**`admin_cidrs` restricted to a single /32.**
Why: the public API is only reachable from my IP. Everything else goes through the private endpoint.

## Files

- `backend.tf`: S3 state, native locking
- `provider.tf`: AWS `~> 5.0`, default tags
- `main.tf`: calls `vpc` then `eks`
- `variables.tf`: no defaults, every value is set in tfvars
- `terraform.tfvars`: committed. Every non-sensitive value, used by both local runs and CI
- `secrets.auto.tfvars`: gitignored. Your IP and admin ARN for local runs (CI gets them from GitHub)

## tfvars

The values are split across two files so there's only one copy of each value.

**`terraform.tfvars`** (committed). Change settings here, and local runs and CI both pick them up:

```hcl
aws_region                = "us-east-1"
environment               = "dev"
owner                     = "your-name"
project_name              = "my-project"
availability_zone_count   = 3
vpc_cidr                  = "10.0.0.0/16"
kubernetes_version        = "<supported version>"
nodes_ami_type            = "AL2023_x86_64_STANDARD"
node_groups = {
  main = {
    instance_type = "m5.xlarge"
    desired_size  = 9
    min_size      = 9
    max_size      = 12
  }
}
retention_in_days         = 90
enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
```

**`secrets.auto.tfvars`** (gitignored). Create it locally:

```hcl
admin_cidrs         = ["203.0.113.5/32"]
admin_principal_arn = "arn:aws:iam::<account-id>:user/<your-user>"
```

In CI, the same two values come from GitHub as `TF_VAR_admin_cidrs` (secret `ADMIN_CIDRS`) and `TF_VAR_admin_principal_arn` (variable `ADMIN_PRINCIPAL_ARN`). When your IP changes, update both the local file and the secret.

## Gotchas

- `admin_principal_arn` has to be set. Bootstrap admin is off, so without it nobody can get in.
- `admin_cidrs = []` means a private API only, so no `kubectl` from home. Add your home IP (`["x.x.x.x/32"]`) so you can use your own terminal. Home IPs do change, so if you're having trouble getting in, check that first (`curl -s https://checkip.amazonaws.com`).
- `desired_size` is ignored after the first apply. Changing a group's `instance_type`, or renaming its key (`main`), replaces that node group.
- To add a node group, add another entry under `node_groups`. No module change needed.
- Check your EC2 vCPU quota before scaling up (9 × m5.xlarge = 36 vCPU).