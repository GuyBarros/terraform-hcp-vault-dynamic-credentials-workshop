vault auth enable ldap


vault write auth/ldap/config \
    url="ldaps://ec2-52-56-199-11.eu-west-2.compute.amazonaws.com" \
    userdn="CN=Users,DC=hashidemos,DC=io" \
    groupdn="OU=Groups,DC=hashidemos,DC=io" \
    groupfilter="(&(objectClass=group)(member:1.2.840.113556.1.4.1941:={{.UserDN}}))" \
    groupattr="cn" \
    upndomain="hashidemos.io" \
    binddn="CN=vaultadmin,CN=Users,DC=hashidemos,DC=io" \
    bindpass='P@ssw0rd' \
    insecure_tls=true \
    starttls=false


    # vault write auth/ldap/groups/engineers policies=foobar$ vault write auth/ldap/users/tesla groups=engineers policies=zoobar

     vault login -method=ldap username=vaultadmin password=P@ssw0rd


#################################################################

vault secrets enable -path=ad_demo openldap



vault write ad_demo/config \
   binddn="CN=vaultadmin,CN=Users,DC=hashidemos,DC=io" \
   bindpass="P@ssw0rd" \
   url="ldap://ec2-18-130-232-151.eu-west-2.compute.amazonaws.com" \
   schema=ad \
   insecure_tls=true \
   starttls=false \
   ttl=10m

tee creation.ldif <<EOF
dn: CN={{.Username}},CN=Users,DC=hashidemos,DC=io
changetype: add
objectClass: top
objectClass: person
objectClass: organizationalPerson
objectClass: user
userPrincipalName: {{.Username}}@hashidemos.io


dn: CN={{.Username}},CN=Users,DC=hashidemos,DC=io
changetype: modify
replace: unicodePwd
unicodePwd::{{ printf "%q" .Password | utf16le | base64 }}
-
replace: userAccountControl
userAccountControl: 66048
-

dn: CN=Hashicorp APP Admins,OU=Groups,DC=hashidemos,DC=io
changetype: modify
add: member
member: CN={{.Username}},CN=Users,DC=Hashidemos,DC=io
-
EOF

tee deletion.ldif <<EOF
dn: CN={{.Username}},CN=Users,DC=Hashidemos,DC=io
changetype: delete
-
EOF

vault write ad_demo/role/dynamic-role2 creation_ldif=@creation.ldif deletion_ldif=@deletion.ldif  default_ttl=5m

vault read ad_demo/creds/dynamic-role2
