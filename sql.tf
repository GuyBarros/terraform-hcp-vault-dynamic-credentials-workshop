resource "aws_db_subnet_group" "databases" {
  name       = "databases"
  subnet_ids  = aws_subnet.demostack.*.id

}

resource "aws_db_instance" "mysql" {
  allocated_storage    = 10
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t3.micro"
  name                 = "mydb"
  username             = "foo"
  password             = "foobarbaz"
  parameter_group_name = "default.mysql5.7"
  db_subnet_group_name = aws_db_subnet_group.databases.id
  vpc_security_group_ids =[aws_security_group.demostack.id]
  skip_final_snapshot  = true
}

# https://github.com/terraform-aws-modules/terraform-aws-rds/tree/master/examples/complete-postgres
resource "aws_db_instance" "postgres" {
engine               = "postgres"
engine_version         = "13.1"
instance_class         = "db.t3.micro"

 allocated_storage      = 5
storage_encrypted     = true

name     = "postgress"
username = "postgresql"
password = "YourPwdShouldBeLongAndSecure!"
port     = 5432
db_subnet_group_name = aws_db_subnet_group.databases.id
vpc_security_group_ids =[aws_security_group.demostack.id]
skip_final_snapshot    = true
}
