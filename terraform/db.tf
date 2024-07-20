# You don't strictly need an RDS instance for your ECS deployment, but this shows you how to create one.

# Every RDS database exists in a subnet group, which is defined here.
# One gotcha I discovered is that if you have to delete and recreate your subnets, at least one of them
# will stick around because of this resource. The only way to get it out of the subnet is either to
# add your RDS instance into another Availability Zone, or to delete your RDS instance and then
# recreate it.
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "db_subnet_group"
  subnet_ids = [for subnet in aws_subnet.public_subnets : subnet.id]
}

resource "aws_db_instance" "mydb" {
  identifier                    = "mydb"
  instance_class                = "db.t3.micro"
  allocated_storage             = 10
  engine                        = "postgres"
  engine_version                = "16.3"
  db_name                       = "mydb"
  db_subnet_group_name          = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids        = [aws_security_group.rds_whitelist.id]
  publicly_accessible           = true
  skip_final_snapshot           = true
  backup_retention_period       = 7

  username                      = "myadmin"

  # By using manage_master_user_password, you instruct AWS to create a secret in SecretsManager,
  # and rotate it weekly. You don't need to know what the password is, you just have to make it
  # available to the ECS task using an IAM task.
  manage_master_user_password   = true
}

# This security group is strictly for convenience. It allows you to access the database directly, using
# the IP address you specified in variables.tf.
resource "aws_security_group" "rds_whitelist" {
  name        = "rds_whitelist"
  description = "whitelist of IP addresses able to access RDS"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["${var.my_ip_address}"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
