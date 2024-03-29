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

echo "==> Docker"

echo "--> Adding keyserver"
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - &>/dev/null

echo "--> Adding repo"
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

echo "--> Updating cache"
apt update -y

echo "--> Installing"
apt install -y docker-ce

echo "--> Allowing docker without sudo"
sudo usermod -aG docker "$(whoami)"

echo "==> Docker is done!"


echo "--> saving the database info"
sudo tee /home/ubuntu/terraform.tfvars > /dev/null <<EOF
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

sudo tee /home/ubuntu/variables.tf > /dev/null <<EOF
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

sudo tee /home/ubuntu/providers.tf > /dev/null <<EOF
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

sudo tee /home/ubuntu/namespaces.tf > /dev/null <<EOF

# create the "mysql" namespace in the default admin namespace
resource "vault_namespace" "mysql" {
  path = "mysql"
}

# create the "postgres" namespace in the default admin namespace
resource "vault_namespace" "postgres" {
  path = "postgres"
}

EOF

sudo tee /home/ubuntu/mysql.tf > /dev/null <<EOF
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

sudo tee /home/ubuntu/postgres.tf > /dev/null <<EOF
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

sudo tee /home/ubuntu/via_generic.tf > /dev/null <<EOF
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
sudo tee /home/ubuntu/config_mysql.sh > /dev/null <<EOF
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

sudo tee /home/ubuntu/config_postgres.sh > /dev/null <<EOF
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

#############################   PKI ##################################################
sudo tee /home/ubuntu/kubernetes_pki.tf > /dev/null <<EOF
resource "vault_mount" "kubernetes_root" {
  path                  = "kubernetes_root"
  type                  = "pki"
  max_lease_ttl_seconds = 315360000 # 10 years
}

resource "vault_pki_secret_backend_root_cert" "kubernetes_root" {
  backend = vault_mount.kubernetes_root.path

  type                 = "internal"
  ttl                  = "87600h"
  key_type             = "rsa"
  exclude_cn_from_sans = true
  ////////////////////////////////////////////////////////////////
  common_name = "kubernetes-ca"
  # ttl = "15768000s"
  format             = "pem"
  private_key_format = "der"
  # key_type = "rsa"
  key_bits = 2048
  # exclude_cn_from_sans = true
  //////////////////////////////////////////////////////////
}

resource "vault_mount" "kubernetes_int" {
  path                  = "kubernetes_int"
  type                  = "pki"
  max_lease_ttl_seconds = 157680000 # 5 years
}

resource "vault_pki_secret_backend_intermediate_cert_request" "kubernetes_int" {
  backend = vault_mount.kubernetes_int.path

  type        = "internal"
  common_name = "kubernetes-ca"
  key_type    = "rsa"
  key_bits    = "2048"
}

resource "vault_pki_secret_backend_root_sign_intermediate" "kubernetes_int" {
  backend = vault_mount.kubernetes_root.path

  csr                  = vault_pki_secret_backend_intermediate_cert_request.kubernetes_int.csr
  common_name          = "kubernetes-ca"
  ttl                  = "43800h"
  exclude_cn_from_sans = true
}

resource "vault_pki_secret_backend_intermediate_set_signed" "kubernetes_int" {
  backend     = vault_mount.kubernetes_int.path
  certificate = vault_pki_secret_backend_root_sign_intermediate.kubernetes_int.certificate
}

resource "vault_pki_secret_backend_role" "kubernetes-ca" {
  backend = vault_mount.kubernetes_int.path
  name    = "kubernetes-ca"
  # allowed_domains    = ["example.io"]
  allow_bare_domains = true #
  allow_subdomains   = true #
  allow_glob_domains = true #
  allow_any_name     = true # adjust allow_*, flags accordingly
  allow_ip_sans      = true #
  server_flag        = true #
  client_flag        = true #
 key_usage = ["DigitalSignature", "KeyAgreement", "KeyEncipherment","KeyUsageCertSign"]
  max_ttl = "730h" # ~1 month
  ttl     = "730h"
}

resource "vault_pki_secret_backend_role" "kube-apiserver-kubelet-client" {
  backend = vault_mount.kubernetes_int.path
  name    = "kubernetes-ca"
  # allowed_domains    = ["example.io"]
  allow_bare_domains = true #
  allow_subdomains   = true #
  allow_glob_domains = true #
  allow_any_name     = true # adjust allow_*, flags accordingly
  allow_ip_sans      = true #
  server_flag        = true #
  client_flag        = true #
  organization       = ["system:masters"]
 key_usage = ["DigitalSignature", "KeyAgreement", "KeyEncipherment","KeyUsageCertSign"]
  max_ttl = "730h" # ~1 month
  ttl     = "730h"
}
EOF

############################# Github Action runner #####################################
echo "==> Github Actions Runner"
mkdir /home/ubuntu/actions-runner && cd /home/ubuntu/actions-runner

echo "==> Download the latest runner package"
curl -o actions-runner-linux-x64-2.283.1.tar.gz -L https://github.com/actions/runner/releases/download/v2.283.1/actions-runner-linux-x64-2.283.1.tar.gz
echo "==> Validate the hash"
echo "aebaaf7c00f467584b921f432f9f9fb50abf06e1b6b226545fbcbdaa65ed3031  actions-runner-linux-x64-2.283.1.tar.gz" | shasum -a 256 -c
echo "==> Extract the installer"
tar xzf ./actions-runner-linux-x64-2.283.1.tar.gz

echo "--> Giving user ubuntu Read/Write access to vault.d directory"
sudo chown -R ubuntu:ubuntu /home/ubuntu/

cd /home/ubuntu/

############
## Add here the code to fix docker if you continue to have issues with github runners
###########


terraform init



