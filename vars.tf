variable "name" {
  type        = "string"
  description = "Global naming convention"
}

variable "vpc_id" {
  type        = "string"
  description = "Vpc id"
}

variable "key_pair" {
  type        = "string"
  description = "EC2 keypair"
}

variable "instance_type" {
  type        = "string"
  description = "EC2 default instance type"
}

variable "volume_size" {
  type        = "string"
  description = "EBS Volume Size"
}

variable "scaling_adjustment" {
  description = "Adjustment size of scaling EC2 instances"
}

variable "cpu_threshold" {
  type        = "string"
  description = "CloudWatch cpu threshold"
}


variable "alarm_threshold" {
  type        = "string"
  description = "CloudWatch alarm threshold"
}

variable "elb_logs_bucket" {
  type        = "string"
  description = "ELB Access Logs bucket"
}