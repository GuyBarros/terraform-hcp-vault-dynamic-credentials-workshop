# TFC + QR code reader to get the link below

vault secrets enable totp

 vault write totp/keys/tfc url="<TOTP_URI>"

 vault read totp/code/tfc