terraform {
  backend "s3" {
    key    = "terraform.tfstate"
    region = "ap-northeast-1"
  }
}

provider "aws" {
  region = "ap-northeast-1"
}

#########################
# VPC
#########################
module "vpc" {
  source = "git::https://git.dmm.com/sre-terraform/tf-vpc.git?ref=v1.2.0"

  name = "${local.name}"
  tags = "${local.tags}"

  cidr = "${local.workspace["vpc_cidr"]}"

  public_subnets  = "${split(",", local.workspace["public_subnets"])}"
  private_subnets = "${split(",", local.workspace["private_subnets"])}"

  # NATの作成
  single_nat_gateway     = "${local.workspace["vpc_single_nat_gateway"]}"
  one_nat_gateway_per_az = "${local.workspace["vpc_one_nat_gateway_per_az"]}"
}

#########################
# Security Group
#########################
module "alb_sg" {
  source = "git::https://git.dmm.com/sre-terraform/tf-security-group.git?ref=v1.0.0"

  vpc_id = "${module.vpc.vpc_id}"

  name        = "${local.name}-alb"
  description = "${local.name} alb"

  # 80と443ポートへのアクセス許可
  ingress_with_cidr_block_rules = [
    {
      cidr_blocks = "0.0.0.0/0"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "Allow all IP at 80 port"
    },
    {
      cidr_blocks = "${local.workspace["alb_allow_https_cidrs"]}"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      description = "Allow at 443 port"
    },
    {
      cidr_blocks = "${join(",",formatlist("%s/32",module.vpc.nat_public_ips))}"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      description = "Allow at 443 port"
    }
  ]
}

module "alb_rpc_sg" {
  source = "git::https://git.dmm.com/sre-terraform/tf-security-group.git?ref=v1.0.0"

  vpc_id = "${module.vpc.vpc_id}"

  name        = "${local.name}-alb-rpc"
  description = "${local.name} alb-rpc"

  # 80と443ポートへのアクセス許可
  ingress_with_cidr_block_rules = [
    {
      cidr_blocks = "${local.workspace["vpc_cidr"]}"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "Allow VPC IP at 80 port"
    },
    {
      cidr_blocks = "${local.workspace["vpc_cidr"]}"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      description = "Allow VPC IP at 443 port"
    }
  ]
}

module "alb_admin_sg" {
  source = "git::https://git.dmm.com/sre-terraform/tf-security-group.git?ref=v1.0.0"

  vpc_id = "${module.vpc.vpc_id}"

  name        = "${local.name}-alb-admin"
  description = "${local.name} alb admin"

  # 80と443ポートへのアクセス許可
  ingress_with_cidr_block_rules = [
    {
      cidr_blocks = "0.0.0.0/0"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "Allow all IP at 80 port"
    },
    {
      cidr_blocks = "${local.workspace["alb_allow_https_cidrs"]}"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      description = "Allow at 443 port"
    },
    {
      cidr_blocks = "${join(",",formatlist("%s/32",module.vpc.nat_public_ips))}"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      description = "Allow at 443 port"
    }
  ]
}

# VPC Inbound Security Group
module "frontend_sg" {
  source = "git::https://git.dmm.com/sre-terraform/tf-security-group.git?ref=v1.0.0"

  vpc_id = "${module.vpc.vpc_id}"

  name        = "${local.name}-million-frontend"
  description = "${local.name} million-frontend"

  ingress_with_cidr_block_rules = [
    {
      # VPC内からのアクセスを許可
      cidr_blocks = "${local.workspace["vpc_cidr"]}"
      from_port   = 3000
      to_port     = 3000
      protocol    = "tcp"
      description = "Allow access within VPC at 3000 port"
    }
  ]
}

module "api_sg" {
  source = "git::https://git.dmm.com/sre-terraform/tf-security-group.git?ref=v1.0.0"

  vpc_id = "${module.vpc.vpc_id}"

  name        = "${local.name}-million-api"
  description = "${local.name} million-api"

  ingress_with_cidr_block_rules = [
    {
      # VPC内からのアクセスを許可
      cidr_blocks = "${local.workspace["vpc_cidr"]}"
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      description = "Allow access within VPC at 8080 port"
    }
  ]
}

module "rpc_sg" {
  source = "git::https://git.dmm.com/sre-terraform/tf-security-group.git?ref=v1.0.0"

  vpc_id = "${module.vpc.vpc_id}"

  name        = "${local.name}-million-rpc"
  description = "${local.name} million-rpc"

  ingress_with_cidr_block_rules = [
    {
      # VPC内からのアクセスを許可
      cidr_blocks = "${local.workspace["vpc_cidr"]}"
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      description = "Allow access within VPC at 8080 port"
    },
  ]
  ingress_with_security_group_rules = [
    {
      source_security_group_id = "${module.lambda_sg.sg_id}"
      from_port                = 8080
      to_port                  = 8080
      protocol                 = "tcp"
      description              = "Allow access within VPC at 8080 port"
    }
  ]
}

module "admin_sg" {
  source = "git::https://git.dmm.com/sre-terraform/tf-security-group.git?ref=v1.0.0"

  vpc_id = "${module.vpc.vpc_id}"

  name        = "${local.name}-million-admin"
  description = "${local.name} million-admin"

  ingress_with_cidr_block_rules = [
    {
      # VPC内からのアクセスを許可
      cidr_blocks = "${local.workspace["vpc_cidr"]}"
      from_port   = 3000
      to_port     = 3000
      protocol    = "tcp"
      description = "Allow access within VPC at 3000 port"
    }
  ]
}

module "lambda_sg" {
  source = "git::https://git.dmm.com/sre-terraform/tf-security-group.git?ref=v1.0.0"

  vpc_id = "${module.vpc.vpc_id}"

  name        = "${local.name}-million-lambda"
  description = "${local.name} million-lambda"

  ingress_with_cidr_block_rules = [
    {
      # VPC内からのアクセスを許可
      cidr_blocks = "${local.workspace["vpc_cidr"]}"
      from_port   = 0
      to_port     = 0
      protocol    = "tcp"
      description = "Lambda VPC"
    }
  ]
}


module "mysql_sg" {
  source = "git::https://git.dmm.com/sre-terraform/tf-security-group.git?ref=v1.0.0"

  vpc_id = "${module.vpc.vpc_id}"

  name        = "${local.name}-mysql"
  description = "${local.name} mysql"

  ingress_with_security_group_rules = [
    {
      cidr_blocks              = "${local.workspace["vpc_cidr"]}"
      from_port                = 3306
      to_port                  = 3306
      protocol                 = "tcp"
      description              = "Allow access within VPC at 3306 port"
    }
  ]
}

#########################
# ALB
#########################
module "front_alb" {
  source = "git::https://git.dmm.com/sre-terraform/tf-alb.git?ref=v1.3.0"

  name = "${local.name}-front"

  subnets         = "${module.vpc.public_subnets}"
  security_groups = ["${module.alb_sg.sg_id}"]

  acm_arn = "${module.contents_acm.acm_arn}"
  
}

module "api_alb" {
  source = "git::https://git.dmm.com/sre-terraform/tf-alb.git?ref=v1.3.0"

  name = "${local.name}-api"

  subnets         = "${module.vpc.public_subnets}"
  security_groups = ["${module.alb_sg.sg_id}"]

  acm_arn = "${module.contents_acm.acm_arn}"
}

module "rpc_alb" {
  source = "git::https://git.dmm.com/sre-terraform/tf-alb.git?ref=v1.3.0"

  name = "${local.name}-rpc"

  internal        = "true"
  subnets         = "${module.vpc.private_subnets}"
  security_groups = ["${module.alb_rpc_sg.sg_id}"]

  acm_arn = "${module.contents_acm.acm_arn}"
}

module "admin_alb" {
  source = "git::https://git.dmm.com/sre-terraform/tf-alb.git?ref=v1.3.0"

  name = "${local.name}-admin"

  subnets         = "${module.vpc.public_subnets}"
  security_groups = ["${module.alb_admin_sg.sg_id}"]

  acm_arn = "${module.admin_acm.acm_arn}"
}


#########################
# ECS Cluster
#########################
module "ecs" {
  source = "git::https://git.dmm.com/sre-terraform/tf-ecs.git?ref=v1.0.0"
  name   = "${local.name}"
}


#########################
# SQS
#########################
resource "aws_sqs_queue" "mail_queue" {
  name                        = "${local.workspace["mail_sqs_name"]}"
  fifo_queue                  = false
  content_based_deduplication = false
}


resource "aws_sqs_queue" "rpc_queue" {
  name                        = "${local.workspace["rpc_sqs_name"]}"
  fifo_queue                  = false
  content_based_deduplication = false
}

#########################
# SSM Parameter
#########################

resource "aws_ssm_parameter" "mail_queue_url_parameter" {
  name  = "/${local.name}/sqs/mail_queue_url"
  type  = "String"
  value = "${aws_sqs_queue.mail_queue.id}"
}

resource "aws_ssm_parameter" "rpc_queue_url_parameter" {
  name  = "/${local.name}/sqs/rpc_queue_url"
  type  = "String"
  value = "${aws_sqs_queue.rpc_queue.id}"
}

#########################
# Aurora MySQL
#########################
data "aws_ssm_parameter" "database_name" {
  name = "/${local.name}/db/database_name"
}

data "aws_ssm_parameter" "master_username" {
  name = "/${local.name}/db/master_username"
}

data "aws_ssm_parameter" "master_password" {
  name = "/${local.name}/db/master_password"
}

module "mysql" {
  source = "/root/git/tf-aurora"

  name = "${local.name}"

  subnets            = "${module.vpc.private_subnets}"
  security_group_ids = ["${module.mysql_sg.sg_id}"]

  # DB接続情報
  database_name   = "${data.aws_ssm_parameter.database_name.value}"
  master_username = "${data.aws_ssm_parameter.master_username.value}"
  master_password = "${data.aws_ssm_parameter.master_password.value}"

  # インスタンスクラス
  instance_class = "${local.workspace["mysql_instance_class"]}"

  # 削除保護
  deletion_protection = "${local.workspace["mysql_deletion_protection"]}"

  # オートスケールの最小・最大
  replica_scale_min = "${local.workspace["mysql_replica_scale_min"]}"
  replica_scale_max = "${local.workspace["mysql_replica_scale_max"]}"
}

#########################
# Route53 A Record
#########################
data "aws_route53_zone" "front_record_domain_zone" {
  name = "${local.workspace["domain_front_zone"]}"
}

resource "aws_route53_record" "front_alb_a_record" {
  zone_id = "${data.aws_route53_zone.front_record_domain_zone.zone_id}"
  name    = "${local.workspace["domain_front_name"]}"
  type    = "A"

  alias {
    name                   = "${module.front_alb.alb_dns_name}"
    zone_id                = "${module.front_alb.alb_zone_id}"
    evaluate_target_health = true
  }
}

data "aws_route53_zone" "api_record_domain_zone" {
  name = "${local.workspace["domain_api_zone"]}"
}

resource "aws_route53_record" "api_alb_a_record" {
  zone_id = "${data.aws_route53_zone.api_record_domain_zone.zone_id}"
  name    = "${local.workspace["domain_api_name"]}"
  type    = "A"

  alias {
    name                   = "${module.api_alb.alb_dns_name}"
    zone_id                = "${module.api_alb.alb_zone_id}"
    evaluate_target_health = true
  }
}

data "aws_route53_zone" "rpc_record_domain_zone" {
  name = "${local.workspace["domain_rpc_zone"]}"
}

resource "aws_route53_record" "rpc_alb_a_record" {
  zone_id = "${data.aws_route53_zone.rpc_record_domain_zone.zone_id}"
  name    = "${local.workspace["domain_rpc_name"]}"
  type    = "A"

  alias {
    name                   = "${module.rpc_alb.alb_dns_name}"
    zone_id                = "${module.rpc_alb.alb_zone_id}"
    evaluate_target_health = true
  }
}

#########################
# Route53 Private Zone
# Private Zoneがdmm.comの場合、パブリック側のdmm.comのレコードが返ってこなくなるためそれぞれをapex zoneとして定義する
# https://docs.aws.amazon.com/ja_jp/Route53/latest/DeveloperGuide/hosted-zone-private-considerations.html
#########################

resource "aws_route53_zone" "private_zone_kakunin_api" {
  name = "${local.workspace["domain_kakunin_api_zone_name"]}"

  vpc {
    vpc_id = "${module.vpc.vpc_id}"
  }
}

resource "aws_route53_record" "private_kakunin_api_a_record" {
  zone_id = "${aws_route53_zone.private_zone_kakunin_api.zone_id}"
  name    = "${local.workspace["domain_kakunin_api_name"]}"
  type    = "A"
  ttl     = "30"
  records = ["${local.workspace["domain_kakunin_api_ip"]}"]
}

resource "aws_route53_zone" "private_zone_marketing_api" {
  name = "${local.workspace["domain_marketing_api_zone_name"]}"

  vpc {
    vpc_id = "${module.vpc.vpc_id}"
  }
}

resource "aws_route53_record" "private_marketing_api_a_record" {
  zone_id = "${aws_route53_zone.private_zone_marketing_api.zone_id}"
  name    = "${local.workspace["domain_marketing_api_name"]}"
  type    = "A"
  ttl     = "30"
  records = ["${local.workspace["domain_marketing_api_ip"]}"]
}

#########################
# ACM 証明書発行
#########################

module "contents_acm" {
  source = "git::https://git.dmm.com/sre-terraform/tf-acm.git?ref=v1.0.0"
  name = "${local.name}-contents"

  hostzones = ["${local.workspace["domain_front_name"]}"]
  domains = ["${local.workspace["domain_front_name"]}", "${local.workspace["domain_api_name"]}", "${local.workspace["domain_rpc_name"]}"]
}

module "admin_acm" {
  source = "git::https://git.dmm.com/sre-terraform/tf-acm.git?ref=v1.0.0"
  name = "${local.name}-admin"

  hostzones = ["${local.workspace["domain_admin_zone"]}"]
  domains = ["${substr(local.workspace["domain_admin_zone"],0,length(local.workspace["domain_admin_zone"])-1)}", "${local.workspace["domain_admin_name"]}"]
}
