output "ecs_alb_dns" {
  value = "${module.fargate_alb.dns_name}"
}
