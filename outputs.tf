////////////////////// Databases //////////////////////////
//MySQL
output "mysql_username" {
  value     = aws_db_instance.mysql.username
  sensitive = false
}

output "mysql_password" {
  value     = aws_db_instance.mysql.password
  sensitive = true
}

output "mysql_hostname" {
  value     = aws_db_instance.mysql.address
  sensitive = false
}

output "mysql_port" {
  value     = aws_db_instance.mysql.port
  sensitive = false
}

output "mysql_name" {
  value     = aws_db_instance.mysql.name
  sensitive = false
}

//PostgresSQL
output "postgres_username" {
  value     = aws_db_instance.postgres.username
  sensitive = false
}

output "postgres_password" {
  value     = aws_db_instance.postgres.password
  sensitive = true
}

output "postgres_hostname" {
  value     = aws_db_instance.postgres.address
  sensitive = false
}

output "postgres_port" {
  value     = aws_db_instance.postgres.port
  sensitive = false
}

output "postgres_name" {
  value     = aws_db_instance.postgres.name
  sensitive = false
}

////////////////////// AWS //////////////////////
output "workers" {
  value = aws_instance.workers.public_dns
}

////////////////////// HCP //////////////////////
output "hcp_vault_private_address" {
  value = hcp_vault_cluster.hcp_demostack.vault_private_endpoint_url
}