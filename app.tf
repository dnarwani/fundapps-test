provider "aws" {
  region = "eu-west-2"
}

##############################################################
# Data sources to get subnets and AMI
##############################################################


data "aws_subnet_ids" "all" {
  vpc_id = "${var.vpc_id}"
}


data "aws_ami" "amazon_linux" {
  most_recent = true

  filter {
    name = "name"

    values = [
      "amzn-ami-hvm-*-x86_64-gp2",
    ]
  }

  filter {
    name = "owner-alias"

    values = [
      "amazon",
    ]
  }
}

##############################################################
# IAM module to allow EC2 access to S3
##############################################################

module "iam" {
	source 		= "modules/iam"

	name 			= "${var.name}"
}

##############################################################
# Security Group module to allow ELB and EC2
##############################################################

module "ec2_sg" {
  source 									= "github.com/terraform-aws-modules/terraform-aws-security-group"

  name        						= "${var.name}-app-sg"
  description 						= "Security group for application tier"
  vpc_id      						= "${var.vpc_id}"

  ingress_cidr_blocks     = ["0.0.0.0/0"]
  ingress_rules           = ["ssh-tcp", "http-80-tcp", "https-443-tcp"]
  egress_rules 						= ["all-all"]
  egress_cidr_blocks    	= ["0.0.0.0/0"]
}


##############################################################
# Application ELB creation
##############################################################

module "elb" {
  source 									= "github.com/terraform-aws-modules/terraform-aws-elb"

  name 										= "${var.name}-elb"

  subnets         				= ["${data.aws_subnet_ids.all.ids}"]
  security_groups 				= ["${module.ec2_sg.this_security_group_id}"]
  internal        				= false

  listener = [
    {
      instance_port     	= "80"
      instance_protocol 	= "HTTP"
      lb_port           	= "80"
      lb_protocol       	= "HTTP"
    },
  ]

  health_check = [
    {
      target              = "TCP:80"
      interval            = 30
      healthy_threshold   = 2
      unhealthy_threshold = 2
      timeout             = 5
    },
  ]

  access_logs = [
    {
      bucket = "${var.elb_logs_bucket}"
    },
  ]

  tags = {
    Owner       = "env"
    Environment = "dev"
  }
}

##############################################################
# Autoscaling with Launch Configuration 
##############################################################

module "asg" {
  source 											= "github.com/terraform-aws-modules/terraform-aws-autoscaling"

  name 												= "${var.name}-app"

  lc_name 										= "${var.name}-lc"

  associate_public_ip_address = true
  image_id        						= "${data.aws_ami.amazon_linux.id}"
  iam_instance_profile 				= "${module.iam.arn}"
  key_name										= "${var.key_pair}"
  instance_type   						= "${var.instance_type}"
  security_groups 						= ["${module.ec2_sg.this_security_group_id}"]
  load_balancers  						= ["${module.elb.this_elb_id}"]

  user_data = <<-EOF
                #!/bin/bash
                yum -y update
								yum install -y httpd
								service httpd start
								chkconfig httpd on
								EOF

  ebs_block_device = [
    {
      device_name           = "/dev/xvdz"
      volume_type           = "gp2"
      volume_size           = "${var.volume_size}"
      delete_on_termination = true
    },
  ]

  root_block_device = [
    {
      volume_size = "${var.volume_size}"
      volume_type = "gp2"
    },
  ]

  asg_name                  = "${var.name}-asg"
  vpc_zone_identifier       = ["${data.aws_subnet_ids.all.ids}"]
  health_check_type         = "EC2"
  min_size                  = 1
  max_size                  = 2
  desired_capacity          = 1
  wait_for_capacity_timeout = 0

  tags = [
    {
      key                 	= "env"
      value               	= "dev"
      propagate_at_launch 	= true
    },
    {
      key                 	= "owner"
      value               	= "dhirajnarwani"
      propagate_at_launch 	= true
    },
  ]
}

##############################################################
# Autoscaling Policies
##############################################################

resource "aws_autoscaling_policy" "asg_policy" {
  name                   		= "${var.name}-app-asg-policy"
  scaling_adjustment     		= "${var.scaling_adjustment}"
  adjustment_type        		= "ChangeInCapacity"
  cooldown               		= 300
  autoscaling_group_name 		= "${module.asg.this_autoscaling_group_name}"
}

##############################################################
# ELB CloudWatch Alarms
##############################################################

resource "aws_cloudwatch_metric_alarm" "cw_alarm_cpu_utilisation" {
  alarm_name 								= "${var.name}-app-CPUUtilization"
  comparison_operator 			= "GreaterThanOrEqualToThreshold"
  evaluation_periods 				= "2"
  metric_name 							= "CPUUtilization"
  namespace 								= "AWS/EC2"
  period 										= "60"
  statistic 								= "Average"
  threshold 								= "${var.cpu_threshold}"
  dimensions {
    AutoScalingGroupName 		= "${module.asg.this_autoscaling_group_name}"
  }
  alarm_description 				= "75% cpu utilisation reached"
  alarm_actions     				= ["${aws_autoscaling_policy.asg_policy.arn}"]
}

resource "aws_cloudwatch_metric_alarm" "cw_alarm_unhealthy" {
  alarm_name	 							= "${var.name}-app-UnHealthyHostCount"
  alarm_description 				= "ELB reports unhealthy registered instance(s)"
  comparison_operator 			= "GreaterThanThreshold"
  evaluation_periods 				= "2"
  metric_name 							= "UnHealthyHostCount"
  namespace 								= "AWS/ELB"
  period 										= "60"
  statistic 								= "Sum"
  threshold 								= "${var.alarm_threshold}"
  dimensions {
    LoadBalancerName 				= "${module.elb.this_elb_name}"
  }
}


