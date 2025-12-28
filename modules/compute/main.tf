data "aws_region" "current" {}

# Amazon Linux 2023 via SSM store
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}


# IAM for SSM (no SSH keys)

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ssm_role" {
  name               = "${var.env}-ec2-ssm-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.env}-ec2-profile"
  role = aws_iam_role.ssm_role.name
}


# ALB + Target Groups

resource "aws_lb" "this" {
  name               = "${var.env}-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [var.alb_sg_id]
  subnets         = var.public_subnet_ids

  tags = {
    Name = "${var.env}-alb"
  }
}

resource "aws_lb_target_group" "blue" {
  name        = "${var.env}-tg-blue"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    path                = "/"
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_target_group" "green" {
  name        = "${var.env}-tg-green"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    path                = "/"
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "forward"

    forward {
      target_group {
        arn    = aws_lb_target_group.blue.arn
        weight = var.blue_weight
      }

      target_group {
        arn    = aws_lb_target_group.green.arn
        weight = var.green_weight
      }

      stickiness {
        enabled  = false
        duration = 1
      }
    }
  }
}


# User data 

locals {
  user_data_blue = <<-EOF
    #!/bin/bash
    set -euxo pipefail

    mkdir -p /opt/web

    TOKEN="$(curl -sX PUT "http://169.254.169.254/latest/api/token" \
      -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")"

    IID="$(curl -sH "X-aws-ec2-metadata-token: $TOKEN" \
      http://169.254.169.254/latest/meta-data/instance-id)"

    test -n "$IID"

    {
      printf '%s\n' '<html>'
      printf '%s\n' '  <body style="font-family: Arial;">'
      printf '%s\n' '    <h1>BLUE</h1>'
      printf '    <p>Instance: %s</p>\n' "$IID"
      printf '%s\n' '  </body>'
      printf '%s\n' '</html>'
    } > /opt/web/index.html


    cat > /etc/systemd/system/web.service <<'UNIT'
    [Unit]
    Description=Simple Web Server
    After=network-online.target
    Wants=network-online.target

    [Service]
    Type=simple
    WorkingDirectory=/opt/web
    ExecStart=/usr/bin/python3 -m http.server 80
    Restart=always

    [Install]
    WantedBy=multi-user.target
    UNIT

    systemctl daemon-reexec
    systemctl daemon-reload
    systemctl enable --now web.service

    # Hardening: disable SSH (SSM still works)
    systemctl disable --now sshd || true
    systemctl mask sshd || true
  EOF

  user_data_green = <<-EOF
    #!/bin/bash
    set -euxo pipefail

    mkdir -p /opt/web

    TOKEN="$(curl -sX PUT "http://169.254.169.254/latest/api/token" \
      -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")"

    IID="$(curl -sH "X-aws-ec2-metadata-token: $TOKEN" \
      http://169.254.169.254/latest/meta-data/instance-id)"

    test -n "$IID"

    {
      printf '%s\n' '<html>'
      printf '%s\n' '  <body style="font-family: Arial;">'
      printf '%s\n' '    <h1>GREEN</h1>'
      printf '    <p>Instance: %s</p>\n' "$IID"
      printf '%s\n' '  </body>'
      printf '%s\n' '</html>'
    } > /opt/web/index.html


    cat > /etc/systemd/system/web.service <<'UNIT'
    [Unit]
    Description=Simple Web Server
    After=network-online.target
    Wants=network-online.target

    [Service]
    Type=simple
    WorkingDirectory=/opt/web
    ExecStart=/usr/bin/python3 -m http.server 80
    Restart=always

    [Install]
    WantedBy=multi-user.target
    UNIT

    systemctl daemon-reexec
    systemctl daemon-reload
    systemctl enable --now web.service

    # Hardening: disable SSH (SSM still works)
    systemctl disable --now sshd || true
    systemctl mask sshd || true
  EOF
}


# Launch Templates

resource "aws_launch_template" "blue" {
  name_prefix   = "${var.env}-lt-blue-"
  image_id      = data.aws_ssm_parameter.al2023_ami.value
  instance_type = var.instance_type

  update_default_version = true

  iam_instance_profile {
    name = aws_iam_instance_profile.this.name
  }

  vpc_security_group_ids = [var.app_sg_id]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  user_data = base64encode(local.user_data_blue)

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name  = "${var.env}-blue"
      Color = "blue"
    }
  }
}

resource "aws_launch_template" "green" {
  name_prefix   = "${var.env}-lt-green-"
  image_id      = data.aws_ssm_parameter.al2023_ami.value
  instance_type = var.instance_type

  update_default_version = true

  iam_instance_profile {
    name = aws_iam_instance_profile.this.name
  }

  vpc_security_group_ids = [var.app_sg_id]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  user_data = base64encode(local.user_data_green)

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name  = "${var.env}-green"
      Color = "green"
    }
  }
}

# Auto Scaling Groups

resource "aws_autoscaling_group" "blue" {
  name                = "${var.env}-asg-blue"
  desired_capacity    = var.blue_desired
  min_size            = 0
  max_size            = 2
  vpc_zone_identifier = var.private_subnet_ids
  health_check_type   = "ELB"

  target_group_arns = [aws_lb_target_group.blue.arn]

  launch_template {
    id      = aws_launch_template.blue.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    triggers = ["launch_template"]

    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.env}-blue"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "green" {
  name                = "${var.env}-asg-green"
  desired_capacity    = var.green_desired
  min_size            = 0
  max_size            = 2
  vpc_zone_identifier = var.private_subnet_ids
  health_check_type   = "ELB"

  target_group_arns = [aws_lb_target_group.green.arn]

  launch_template {
    id      = aws_launch_template.green.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    triggers = ["launch_template"]

    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.env}-green"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}
