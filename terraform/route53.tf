
resource "aws_route53_zone" "public" {
  name              = "${var.domain_name}."
  comment           = "public zone for ${var.domain_name} (managed by terraform)"
  force_destroy     = false
}

resource "aws_route53_record" "www" {
  zone_id                       = "${aws_route53_zone.public.zone_id}"
  name                          = "www"
  type                          = "A"

  alias {
    name                        = aws_alb.ecs_alb.dns_name
    zone_id                     = aws_alb.ecs_alb.zone_id
    evaluate_target_health      = true
  }
}

resource "aws_route53_record" "root" {
  zone_id                       = "${aws_route53_zone.public.zone_id}"
  name                          = ""
  type                          = "A"

  alias {
    name                        = aws_alb.ecs_alb.dns_name
    zone_id                     = aws_alb.ecs_alb.zone_id
    evaluate_target_health      = true
  }
}

