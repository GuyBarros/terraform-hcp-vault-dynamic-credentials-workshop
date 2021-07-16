#!/bin/bash
set -x

echo "==> Base"


echo "--> Updating apt-cache"
ssh-apt update

echo "--> Adding Hashicorp repo"
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
 sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"

echo "--> Installing common dependencies"
apt-get install -y \
  curl \
  nano \
  git \
  jq \
  unzip \
  vault-enterprise \
  terraform
echo "--> making a path to save vault config files"
sudo mkdir -p /etc/vault.d/


echo "--> saving the database info"
sudo tee /etc/vault.d/terraform.tfvars > /dev/null <<EOF
  hcp_vault_address = "${hcp_vault_addr}"
  #NOTE: your HCP Vault admin token has been added as a env variable automatically
  mysql_hostname = "${mysql_hostname}"
  mysql_port = ${mysql_port}
  mysql_name = "${mysql_name}"
  mysql_username = "${mysql_username}"
  mysql_password = "${mysql_password}"
  postgres_hostname = "${postgres_hostname}"
  postgres_port = ${postgres_port}
  postgres_name = "${postgres_name}"
  postgres_username = "${postgres_username}"
  postgres_password = "${postgres_password}"

EOF

sudo tee /etc/vault.d/variables.tf > /dev/null <<EOF
 variable "hcp_vault_address" {
  description = "private URL for HCP Vault"
}
 variable "hcp_vault_namespace" {
  description = "the HCP Vault namespace we will use for mounting the database secret engine"
  default = "admin"
}

//MySQL
  variable "mysql_hostname" {
  description = "the hostname of the MySQL Database we will configure in Vault"
}

variable "mysql_port" {
  description = "the port of the MySQL Database we will configure in Vault"
}

variable "mysql_name" {
  description = "the Name of the MySQL Database we will configure in Vault"
}

variable "mysql_username" {
  description = "the admin username of the MySQL Database we will configure in Vault"
}

variable "mysql_password" {
  description = "the password for admin username of the MySQL Database we will configure in Vault(this will be rotated after config)"
}

//PostgresSQL
variable "postgres_hostname" {
  description = "the hostname of the MySQL Database we will configure in Vault"
}

variable "postgres_port" {
  description = "the port of the MySQL Database we will configure in Vault"
}

variable "postgres_name" {
  description = "the Name of the MySQL Database we will configure in Vault"
}

variable "postgres_username" {
  description = "the admin username of the MySQL Database we will configure in Vault"
}

variable "postgres_password" {
  description = "the password for admin username of the MySQL Database we will configure in Vault(this will be rotated after config)"
}
EOF

sudo tee /etc/vault.d/providers.tf > /dev/null <<EOF
provider "vault" {
  address = var.hcp_vault_address
  namespace = "admin"
}

# configure an aliased provider, scope to the mysql namespace.
provider vault {
  alias     = "mysql"
  namespace = trimsuffix(vault_namespace.mysql.id, "/")
  address = var.hcp_vault_address
}

# configure an aliased provider, scope to the postgres namespace.
provider vault {
  alias     = "postgres"
  namespace = trimsuffix(vault_namespace.postgres.id, "/")
  address = var.hcp_vault_address
}

EOF

sudo tee /etc/vault.d/namespaces.tf > /dev/null <<EOF

# create the "mysql" namespace in the default admin namespace
resource "vault_namespace" "mysql" {
  path = "mysql"
}

# create the "postgres" namespace in the default admin namespace
resource "vault_namespace" "postgres" {
  path = "postgres"
}

EOF

sudo tee /etc/vault.d/mysql.tf > /dev/null <<EOF
# create a policy in the "mysql" namespace
resource "vault_policy" "mysql" {
  provider = vault.mysql

  depends_on = [vault_namespace.mysql]
  name       = "vault_mysql_policy"
  policy     = data.vault_policy_document.dynamic_database.hcl
}

data "vault_policy_document" "dynamic_database" {
  rule {
    path         = "secret/*"
    capabilities = ["list"]
    description  = "allow List on secrets under everyone/"
  }
  rule {
    path         = "mysql/creds/mysql-role"
    capabilities = ["read", "update"]
    description  = "allow dynamic database credentials for db role mysql-role"
  }
}

resource "vault_mount" "mysql" {
  provider = vault.mysql
  path = "mysql"
  type = "database"
}

resource "vault_database_secret_backend_connection" "mysql-con" {
  provider = vault.mysql
  backend       = vault_mount.mysql.path
  name          = "mysql-con"
  allowed_roles = ["mysql-role"]

mysql_rds{
    connection_url="${mysql_username}:${mysql_password}@tcp(${mysql_hostname}:${mysql_port})/"
    }

}

resource "vault_database_secret_backend_role" "mysql-role" {
  depends_on = [vault_database_secret_backend_connection.mysql-con]
   provider = vault.mysql
  backend             = vault_mount.mysql.path
  name                = "mysql-role"
  db_name             = vault_database_secret_backend_connection.mysql-con.name
  creation_statements = ["CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}';GRANT SELECT ON *.* TO '{{name}}'@'%';"]
}


EOF

sudo tee /etc/vault.d/postgres.tf > /dev/null <<EOF
resource "vault_mount" "postgres" {
  provider = vault.postgres
  path = "postgres"
  type = "database"
}

resource "vault_database_secret_backend_connection" "postgres-con" {
  provider = vault.postgres
  backend       = vault_mount.postgres.path
  name          = "postgres-con"
  allowed_roles = ["postgres-role"]

  postgresql {
    connection_url = "postgres://${postgres_username}:${postgres_password}@${postgres_hostname}:${postgres_port}/${postgres_name}"
  }
}

resource "vault_database_secret_backend_role" "postgres-role" {
  depends_on = [vault_database_secret_backend_connection.postgres-con]
   provider = vault.postgres
  backend             = vault_mount.postgres.path
  name                = "postgres-role"
  db_name             =  vault_database_secret_backend_connection.postgres-con.name
  creation_statements = ["CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';"]
}
EOF

sudo tee /etc/vault.d/via_generic.tf > /dev/null <<EOF
resource "vault_mount" "mysql_api" {
  provider = vault.mysql
  path = "mysql_api"
  type = "database"
}

resource "vault_generic_endpoint" "test_mysqldb" {
  depends_on = [vault_mount.mysql_api]
 provider = vault.mysql

  path = "mysql_api/config/my-mysql-database"
  ignore_absent_fields = true

  data_json = <<EOT
{
    "plugin_name": "mysql-rds-database-plugin",
    "allowed_roles": "mysql_api-role",
    "connection_url":"{{username}}:{{password}}@tcp(${mysql_hostname}:${mysql_port})/" ,
    "username": "${mysql_username}",
    "password": "${mysql_password}"
}
EOT
}

resource "vault_database_secret_backend_role" "mysql_api-role" {
  depends_on = [vault_mount.mysql_api,vault_generic_endpoint.test_mysqldb]
   provider = vault.mysql
  backend             = vault_mount.mysql_api.path
  name                = "mysql_api-role"
  db_name             = "my-mysql-database"
  creation_statements = ["CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}';GRANT SELECT ON *.* TO '{{name}}'@'%';"]
}


EOF

#configure Vault Via Script
sudo tee /etc/vault.d/config_mysql.sh > /dev/null <<EOF
################# MYSQL
 vault secrets enable -path=mysql_script database

vault write mysql_script/config/my-mysql-database \
plugin_name=mysql-rds-database-plugin \
connection_url="{{username}}:{{password}}@tcp(${mysql_hostname}:${mysql_port})/" \
allowed_roles="my-role" \
username="${mysql_username}" \
password="${mysql_password}"

vault write mysql_script/roles/my-role \
    db_name="my-mysql-database" \
    creation_statements="CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}';GRANT SELECT ON *.* TO '{{name}}'@'%';" \
    default_ttl="1h" \
    max_ttl="24h"

vault read mysql/creds/my-role

#############################
EOF

sudo tee /etc/vault.d/config_postgres.sh > /dev/null <<EOF
################# PostGres
 vault secrets enable -path=postgres database

vault write postgres/config/postgresql \
 plugin_name=postgresql-database-plugin \
 connection_url="postgresql://{{username}}:{{password}}@${postgres_hostname}:${postgres_port}/${postgres_name}?sslmode=disable" \
 allowed_roles=readonly \
 username="${postgres_username}" \
 password="${postgres_password}"

 vault write postgres/roles/postgresql \
    db_name="postgresql" \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';"
    default_ttl="1h" \
    max_ttl="24h"

vault read postgres/creds/postgresql

#############################
EOF

export VAULT_TOKEN=${hcp_vault_admin_token}
export VAULT_ADDR=${hcp_vault_addr}
export VAULT_NAMESPACE=admin

echo "export VAULT_TOKEN=$VAULT_TOKEN" >> /home/ubuntu/.bashrc
echo "export VAULT_ADDR=$VAULT_ADDR" >> /home/ubuntu/.bashrc
echo "export VAULT_NAMESPACE=$VAULT_NAMESPACE" >> /home/ubuntu/.bashrc

echo "export VAULT_TOKEN=$VAULT_TOKEN" >> /root/.bashrc
echo "export VAULT_ADDR=$VAULT_ADDR" >> /root/.bashrc
echo "export VAULT_NAMESPACE=$VAULT_NAMESPACE" >> /root/.bashrc

echo "--> Giving user ubuntu Read/Write access to vault.d directory"
sudo chown -R ubuntu:ubuntu /etc/vault.d/
