
locals {
  selected_azs = slice(data.aws_availability_zones.available.names, 0, var.availability_zone_count)

  max_azs = 6
  subnet_config = {
    for idx, az in local.selected_azs : az => {
      az_name         = az
      public_cidr     = cidrsubnet(var.vpc_cidr, 8, idx)
      private_cidr    = cidrsubnet(var.vpc_cidr, 4, idx + 1)
      db_private_cidr = cidrsubnet(var.vpc_cidr, 8, idx + local.max_azs)
    }
  }

  open_internet = "0.0.0.0/0"

}
