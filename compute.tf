# Gzip cloud-init config
data "template_cloudinit_config" "workers" {

  gzip          = true
  base64_encode = true

  part {
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/templates/shared/base.sh", {
      # Database
      #MYSQL
      mysql_username = aws_db_instance.mysql.username
      mysql_password = aws_db_instance.mysql.password
      mysql_hostname = aws_db_instance.mysql.address
      mysql_port     = aws_db_instance.mysql.port
      mysql_name     = aws_db_instance.mysql.name
      # Postgres
      postgres_username = aws_db_instance.postgres.username
      postgres_password = aws_db_instance.postgres.password
      postgres_hostname = aws_db_instance.postgres.address
      postgres_port     = aws_db_instance.postgres.port
      postgres_name     = aws_db_instance.postgres.name
      # HCP Vault
      hcp_vault_addr        = hcp_vault_cluster.hcp_demostack.vault_private_endpoint_url
      hcp_vault_admin_token = hcp_vault_cluster_admin_token.root.token

    })
  }
}

resource "aws_instance" "workers" {

  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type_worker
  key_name      = aws_key_pair.demostack.id

  subnet_id              = aws_subnet.demostack.0.id
  iam_instance_profile   = aws_iam_instance_profile.consul-join.name
  vpc_security_group_ids = [aws_security_group.demostack.id]


  root_block_device {
    volume_size           = "240"
    delete_on_termination = "true"
  }

  ebs_block_device {
    device_name           = "/dev/xvdd"
    volume_type           = "gp2"
    volume_size           = "240"
    delete_on_termination = "true"
  }

  user_data = data.template_cloudinit_config.workers.rendered
}
