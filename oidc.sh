
export ARM_SUBSCRIPTION_ID=<ARM_SUBSCRIPTION_ID>
export ARM_TENANT_ID=<ARM_TENANT_ID>
export ARM_CLIENT_ID=<ARM_CLIENT_ID>
export ARM_CLIENT_SECRET=<ARM_CLIENT_SECRET>
export VAULT_NAMESPACE=<VAULT_NAMESPACE>
export VAULT_TOKEN=<VAULT_TOKEN>
export VAULT_ADDR=<https://VAULT_HOSTNAME:8200>
export VAULT_CALLBACK_ADDR=<https://VAULT_HOSTNAME:8250>




    vault write auth/oidc/config oidc_discovery_url="https://login.microsoftonline.com/$ARM_TENANT_ID/v2.0" oidc_client_id="$ARM_CLIENT_ID" oidc_client_secret="$ARM_CLIENT_SECRET" default_role="oidcdemo"



    vault write auth/oidc/role/oidcdemo bound_audiences="$ARM_CLIENT_ID" \
    allowed_redirect_uris="http://localhost:8250/oidc/callback" \
    allowed_redirect_uris="$VAULT_ADDR/ui/vault/auth/oidc/oidc/callback" \
    allowed_redirect_uris="$VAULT_CALLBACK_ADDR/oidc/callback" \
    user_claim="sub" \
    policies="superuser" \
    claim_mappings={dysplayname=dysplayname,surname=surname,givenname=givenname,preferred_username=preferred_username,unique_name=unique_name,email=email,name=name}

