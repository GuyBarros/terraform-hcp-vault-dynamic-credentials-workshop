vault secrets enable ad


vault write ad/config \
    binddn='vaultadmin' \
    bindpass='P@ssw0rd' \
    url="ldaps://ec2-18-132-2-129.eu-west-2.compute.amazonaws.com" \
    userdn="CN=Users,DC=hashidemos,DC=io" \
    upndomain="hashidemos.io" \
    insecure_tls=true \
    starttls=false \
   ttl=10m

vault write ad/roles/hashidemo   service_account_name="hashidemo@hashidemos.io"

vault read ad/creds/hashidemo