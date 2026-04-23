#!/bin/bash
set -e

# Set current user principal_id --- needed for the RBAC
azd env set USER_PRINCIPAL_ID "$(az ad signed-in-user show --query id -o tsv)"

# Check web app registration
webApp=$(az ad app list --filter "displayName eq 'Fraud Detection Angular App'" --query "[0].appId" -o tsv)
if [ -n "$webApp" ]; then
    azd env set WEB_APP_CLIENT_ID "$webApp"
fi

# Check function app registration
funcApp=$(az ad app list --filter "displayName eq 'Fraud-Agent-Function'" --query "[0].appId" -o tsv)
if [ -n "$funcApp" ]; then
    azd env set FUNC_APP_CLIENT_ID "$funcApp"

    # Capture existing OAuth2 permission scope ID to keep it stable across deployments
    scopeId=$(az ad app list --filter "displayName eq 'Fraud-Agent-Function'" --query "[0].api.oauth2PermissionScopes[0].id" -o tsv)
    if [ -n "$scopeId" ]; then
        azd env set OAUTH2_FUNC_ID "$scopeId"
    fi
fi