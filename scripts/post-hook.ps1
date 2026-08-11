Write-Host "Building and deploying web frontend..."

# Read azd env values (populated from Bicep outputs)
$ACR_NAME = azd env get-value AZURE_CONTAINER_REGISTRY_NAME
$RG = azd env get-value AZURE_RESOURCE_GROUP
$WEBAPP_NAME = azd env get-value AZURE_FRONTEND_WEBAPP_NAME
$ACR_ENDPOINT = azd env get-value AZURE_CONTAINER_REGISTRY_ENDPOINT
$IMAGE = "${ACR_ENDPOINT}/web:latest"

# Read values for environment.prod.ts replacement
$CLIENT_ID = azd env get-value FRONTEND_CLIENTID
$AUTHORITY = azd env get-value AUTHORITY
$API_SCOPES = azd env get-value FUNCTION_SCOPE
$API_BASE_URL = azd env get-value FUNCTION_BASE_URL
$REDIRECT_URL = azd env get-value FRONTEND_REDIRECT_URL
$APPINSIGHT_KEY = azd env get-value APPLICATION_INSIGHTS_KEY

# Temporarily inject real values into environment.prod.ts for the Docker build
$envFile = "./src/web/src/app/environments/environment.prod.ts"
$originalContent = Get-Content $envFile -Raw

$updatedContent = $originalContent `
    -replace '__clientId__', $CLIENT_ID `
    -replace '__authority__', $AUTHORITY `
    -replace '__apiScopes__', $API_SCOPES `
    -replace '__apiBaseUrl__', $API_BASE_URL `
    -replace '__redirectUrl__', $REDIRECT_URL `
    -replace '__appInsightKey__', $APPINSIGHT_KEY

Write-Host "Injecting environment values into environment.prod.ts for Docker build..."
Set-Content -Path $envFile -Value $updatedContent -NoNewline

# Write replaced content to a separate file for verification
$replaceFile = "./src/web/src/app/environments/environment.replace.ts"
Write-Host "Writing resolved values to $replaceFile for verification..."
Set-Content -Path $replaceFile -Value $updatedContent -NoNewline

try {
    Write-Host "Logging on ACR: $ACR_NAME ..."
    az acr login --name $ACR_NAME

    Write-Host "Building Image: web:latest ..."
    docker build -t "${ACR_ENDPOINT}/web:latest" ./src/web

    Write-Host "Pushing image on ACR: $ACR_NAME ..."
    docker push "${ACR_ENDPOINT}/web:latest"
}
finally {
    # Always restore the original file so the repo stays clean
    Write-Host "Restoring original environment.prod.ts..."
    Set-Content -Path $envFile -Value $originalContent -NoNewline
}

# Point the Web App to the ACR image (Bicep uses a placeholder for first deploy)
Write-Host "Configuring Web App: $WEBAPP_NAME to use image $IMAGE ..."
az webapp config container set `
    --name $WEBAPP_NAME `
    --resource-group $RG `
    --container-image-name $IMAGE `
    --container-registry-url "https://${ACR_ENDPOINT}"

Write-Host "Restarting Web App: $WEBAPP_NAME ..."
az webapp restart --name $WEBAPP_NAME --resource-group $RG

Write-Host "Deployment complete."