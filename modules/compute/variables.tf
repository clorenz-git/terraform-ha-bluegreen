variable "env" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "alb_sg_id" {
  type = string
}

variable "app_sg_id" {
  type = string
}

# keep this tiny to avoid spend
variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "blue_desired" {
  type    = number
  default = 1
}

variable "green_desired" {
  type    = number
  default = 1
}

variable "blue_weight" {
  type    = number
  default = 0
}

variable "green_weight" {
  type    = number
  default = 100
}
