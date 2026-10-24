
locals {
  selected_azs = slice(data.aws_availability_zones.available.names, 0, var.availability_zone_count)
  subnet_config = {
    for idx, az in local.selected_azs : az => {
      az_name         = az
      public_cidr     = cidrsubnet(var.vpc_cidr, 8, idx)
      private_cidr    = cidrsubnet(var.vpc_cidr, 8, idx + var.availability_zone_count)
      db_private_cidr = cidrsubnet(var.vpc_cidr, 8, idx + var.availability_zone_count * 2)
    }
  }
  
  open_internet = "0.0.0.0/0"

}