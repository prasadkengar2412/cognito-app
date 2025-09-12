#!/usr/bin/env python3
import sys
import os
import json
import boto3
from botocore.exceptions import ClientError

def load_json(path, max_size=2 * 1024 * 1024):
    """Load and validate JSON file with size check."""
    if not os.path.exists(path):
        raise FileNotFoundError(f"File not found: {path}")
    
    size = os.path.getsize(path)
    if size > max_size:
        raise ValueError(f"File {path} exceeds {max_size} bytes (got {size})")
    
    with open(path, "r") as f:
        return json.load(f)

def main():
    if len(sys.argv) != 7:
        print("Usage: manage_cognito_branding.py <pool_id> <client_id> <region> <settings_file> <assets_file> <app_name>")
        sys.exit(1)

    pool_id, client_id, region, settings_file, assets_file, app_name = sys.argv[1:]

    cognito = boto3.client("cognito-idp", region_name=region)

    try:
        settings = load_json(settings_file)
        assets = load_json(assets_file)
    except Exception as e:
        print(f"❌ Error loading files: {e}", file=sys.stderr)
        sys.exit(1)

    try:
        resp = cognito.describe_managed_login_branding_by_client(
            UserPoolId=pool_id,
            ClientId=client_id
        )
        branding_id = resp.get("ManagedLoginBranding", {}).get("ManagedLoginBrandingId")

        if branding_id:
            print(f"ℹ️ Branding exists (ID: {branding_id}), updating...")
            cognito.update_managed_login_branding(
                UserPoolId=pool_id,
                ManagedLoginBrandingId=branding_id,
                Settings=json.dumps(settings),
                Assets=json.dumps(assets),
            )
            print(f"✅ Branding updated for {app_name}")
        else:
            print(f"⚠️ Branding ID missing, creating new branding...")
            cognito.create_managed_login_branding(
                UserPoolId=pool_id,
                ClientId=client_id,
                Settings=json.dumps(settings),
                Assets=json.dumps(assets),
            )
            print(f"✅ Branding created for {app_name}")

    except ClientError as e:
        print(f"❌ AWS Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
