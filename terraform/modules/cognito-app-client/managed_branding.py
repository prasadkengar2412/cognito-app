#!/usr/bin/env python3
import json
import sys
import boto3
import botocore.exceptions

def main():
    # Read input from Terraform
    input_data = json.load(sys.stdin)
    user_pool_id = input_data["user_pool_id"]
    client_id = input_data["client_id"]
    settings_path = input_data["settings_path"]
    assets_path = input_data["assets_path"]
    region = input_data["region"]

    # Initialize boto3 client
    cognito = boto3.client("cognito-idp", region_name=region)

    # Read JSON files
    try:
        with open(settings_path, "r") as f:
            settings = json.load(f)
        with open(assets_path, "r") as f:
            assets = json.load(f)
    except Exception as e:
        print(f"Error reading JSON files: {str(e)}", file=sys.stderr)
        sys.exit(1)

    # Describe existing branding configurations
    branding_id = None
    try:
        response = cognito.describe_managed_login_branding(UserPoolId=user_pool_id)
        for branding in response.get("ManagedLoginBrandings", []):
            if branding.get("ClientId") == client_id:
                branding_id = branding.get("ManagedLoginBrandingId")
                break
        print(f"DEBUG: Describe response: {json.dumps(response)}", file=sys.stderr)
    except cognito.exceptions.ClientError as e:
        print(f"DEBUG: Describe failed: {str(e)}", file=sys.stderr)
        if e.response["Error"]["Code"] != "ResourceNotFoundException":
            print(f"Error describing branding: {str(e)}", file=sys.stderr)
            sys.exit(1)

    # Create or update branding
    if not branding_id:
        print(f"DEBUG: Creating new branding for client {client_id}", file=sys.stderr)
        try:
            response = cognito.create_managed_login_branding(
                UserPoolId=user_pool_id,
                ClientIds=[client_id],
                Settings=settings,
                Assets=assets
            )
            branding_id = response.get("ManagedLoginBrandingId")
            print(f"DEBUG: Created branding with ID: {branding_id}", file=sys.stderr)
        except cognito.exceptions.ClientError as e:
            print(f"Error creating branding: {str(e)}", file=sys.stderr)
            if e.response["Error"]["Code"] == "ManagedLoginBrandingExistsException":
                # Fallback: Try to find existing ID
                response = cognito.describe_managed_login_branding(UserPoolId=user_pool_id)
                for branding in response.get("ManagedLoginBrandings", []):
                    if branding.get("ClientId") == client_id:
                        branding_id = branding.get("ManagedLoginBrandingId")
                        print(f"DEBUG: Found existing branding ID: {branding_id}", file=sys.stderr)
                        break
                if not branding_id:
                    print("Error: Failed to find existing branding ID", file=sys.stderr)
                    sys.exit(1)
            else:
                sys.exit(1)

    # Update branding
    print(f"DEBUG: Updating branding with ID: {branding_id}", file=sys.stderr)
    try:
        cognito.update_managed_login_branding(
            UserPoolId=user_pool_id,
            ManagedLoginBrandingId=branding_id,
            ClientIds=[client_id],
            Settings=settings,
            Assets=assets
        )
        print("DEBUG: Branding update successful", file=sys.stderr)
    except cognito.exceptions.ClientError as e:
        print(f"Error updating branding: {str(e)}", file=sys.stderr)
        sys.exit(1)

    # Output for Terraform
    print(json.dumps({"branding_id": branding_id}))

if __name__ == "__main__":
    main()
