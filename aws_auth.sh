

vault auth enable aws

vault write auth/aws/config/client secret_key=<KEY> access_key=<USER>

vault write auth/aws/role/<EC2_INSTANCE_ROLE> auth_type=iam bound_iam_role_arn=arn:aws:iam::<accountID>:role/<EC2_INSTANCE_ROLE_ARN> policies=hcp_root inferred_entity_type=ec2_instance inferred_aws_region=eu-west-2




vault login -method=aws role=test-role