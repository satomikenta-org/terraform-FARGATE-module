
provider "aws" {
  region = "${var.aws_region}"
}

resource "aws_ecs_cluster" "cluster" {
  name = "${var.project_name}-ecs-cluster"
}

data "aws_vpc" "main" {
  default = true
}

data "aws_subnet_ids" "main" {
  vpc_id = "${data.aws_vpc.main.id}"
}

module "fargate_alb" {
  source  = "telia-oss/loadbalancer/aws"
  version = "0.1.0"

  name_prefix = "${var.project_name}"
  type        = "application"
  internal    = "false"
  vpc_id      = "${data.aws_vpc.main.id}"
  subnet_ids  = ["${data.aws_subnet_ids.main.ids}"]

  tags {
    environment = "test"
    terraform   = "true"
  }
}

resource "aws_lb_listener" "alb" {
  load_balancer_arn = "${module.fargate_alb.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${module.fargate.target_group_arn}"
    type             = "forward"
  }
}

resource "aws_security_group_rule" "task_ingress_8000" {
  security_group_id        = "${module.fargate.service_sg_id}"
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = "${var.container_port}"
  to_port                  = "${var.container_port}"
  source_security_group_id = "${module.fargate_alb.security_group_id}" # only accept tcp from ALB
}

resource "aws_security_group_rule" "alb_ingress_80" {
  security_group_id = "${module.fargate_alb.security_group_id}"
  type              = "ingress"
  protocol          = "tcp"
  from_port         = "80"
  to_port           = "80"
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
}


module "fargate" {
  source = "telia-oss/ecs-fargate/aws"

  name_prefix          = "${var.project_name}"
  vpc_id               = "${data.aws_vpc.main.id}"
  private_subnet_ids   = "${data.aws_subnet_ids.main.ids}"
  cluster_id           = "${aws_ecs_cluster.cluster.id}"
  task_container_image = "${var.ecr_repository_url}"
  desired_count = "${var.container_desired_count}"
  
  // public ip is needed for default vpc, default is false
  task_container_assign_public_ip = "true"

  // port, default protocol is HTTP
  task_container_port = "${var.container_port}"

  health_check {
    port = "traffic-port"
    path = "${var.health_check_path}"
  }

  tags {
    environment = "test"
    terraform   = "true"
  }

  lb_arn = "${module.fargate_alb.arn}"
}