vault secrets enable ad


vault write ad/config \
    binddn='Administrator' \
    bindpass='U95bjEQ;p$7H4N2b(L%GIrF7$VSfs**g' \
    url="ldap://ec2-18-130-232-151.eu-west-2.compute.amazonaws.com" \
    userdn="CN=Users,DC=hashidemos,DC=io" \
    upndomain="hashidemos.io" \
    insecure_tls=true \
    starttls=false \
   ttl=10m

vault write ad/roles/hashidemo   service_account_name="vaultadmin@hashidemos.io"

    vault read ad/creds/hashidemo