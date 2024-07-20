
####################################################
# ALB security group
resource "aws_security_group" "ecs_alb_sg" {
  name        = "ecs_alb_sg"
  description = "Allow 80 and 443 inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ecs_service_sg" {
  name        = "ecs_service_sg"
  description = "Allow 80 inbound traffic and all outbound traffic with the ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port        = 3000 # has to match the container port in the ECS task definition
    to_port          = 3000
    protocol         = "tcp"
    security_groups  = [aws_security_group.ecs_alb_sg.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
}

####################################################
# Certs for mydomain.com and www.mydomain.com

# Cert for the root domain (e.g., mydomain.com)
resource "aws_acm_certificate" "mycert" {
  domain_name               = "${var.domain_name}"
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy   = true
  }
}

# When we create an ACM certificate, the validation method is "DNS". To validate that we have the domain,
# we have to create a CNAME in the domain. This is the magic code that does that.
resource "aws_route53_record" "mycert_cname" {
  for_each = {
    for dvo in aws_acm_certificate.mycert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.public.zone_id
}

# Cert for the www domain (e.g., www.mydomain.com)
resource "aws_acm_certificate" "www_cert" {
  domain_name               = "www.${var.domain_name}"
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy   = true
  }
}

# When we create an ACM certificate, the validation method is "DNS". To validate that we have the domain,
# we have to create a CNAME in the domain. This is the magic code that does that.
resource "aws_route53_record" "www_cert_cname" {
  for_each = {
    for dvo in aws_acm_certificate.www_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.public.zone_id
}

####################################################
# ALB definition
resource "aws_alb" "ecs_alb" {
  internal                        = false
  load_balancer_type              = "application"
  security_groups                 = [aws_security_group.ecs_alb_sg.id]  # only allow incoming on ports 80 and 443
  subnets                         = [for subnet in aws_subnet.public_subnets : subnet.id]  # only connect to the public subnets
  enable_deletion_protection      = true
}

# The target group defines where incoming traffic is going to go, as well as a health check
resource "aws_lb_target_group" "my_target_group" {
  name                      = "my-target-group"
  port                      = 3000
  protocol                  = "HTTP"
  target_type               = "ip"
  vpc_id                    = aws_vpc.main.id
  health_check {
      path                  = "/"
      protocol              = "HTTP"
      matcher               = "200"
      port                  = "traffic-port"
      healthy_threshold     = 2
      unhealthy_threshold   = 2
      timeout               = 10
      interval              = 30
  }
}

# When traffic comes in on port 443, use the cert to terminate SSL, and forward to my_target_group
resource "aws_lb_listener" "ecs_alb_listener" {
  load_balancer_arn = aws_alb.ecs_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.mycert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my_target_group.arn
  }
}

# Associate the www_cert with the ecs_alb_listener. Note that we already associated mycert with ecs_alb_listener
# in its definition (see above) – to associate other certs with the listener, you have to use an
# aws_lb_listener_certificate resource.
resource "aws_lb_listener_certificate" "www_cert" {
  listener_arn    = aws_lb_listener.ecs_alb_listener.arn
  certificate_arn = aws_acm_certificate.www_cert.arn
}

# If the traffic comes in on port 80, redirect to port 443. We don't want to accept unencrypted requests.
resource "aws_lb_listener" "redirect_to_443" {
  load_balancer_arn = "${aws_alb.ecs_alb.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# If someone sends a request to www.mydomain.com, redirect to mydomain.com
resource "aws_lb_listener_rule" "redirect_www_to_root" {
  listener_arn = aws_lb_listener.ecs_alb_listener.arn
  priority     = 50

  action {
    type = "redirect"

    redirect {
      host        = var.domain_name
      path        = "/#{path}"
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  condition {
    host_header {
      values = ["www.${var.domain_name}"]
    }
  }
}

