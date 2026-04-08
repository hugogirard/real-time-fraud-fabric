Write-Host "Building and deploying web frontend..."

# Read azd env values (populated from Bicep outputs)
$ACR_NAME = azd env get-value AZURE_CONTAINER_REGISTRY_NAME
$RG = azd env get-value AZURE_RESOURCE_GROUP
$WEBAPP_NAME = azd env get-value AZURE_FRONTEND_WEBAPP_NAME
$ACR_ENDPOINT = azd env get-value AZURE_CONTAINER_REGISTRY_ENDPOINT
$IMAGE = "${ACR_ENDPOINT}/web:latest"

Write-Host "Logging on ACR: $ACR_NAME ..."
az acr login --name $ACR_NAME

Write-Host "Buiding Image: web:latest ..."
docker build -t "${ACR_ENDPOINT}/web:latest" ./src/web

# Build container image remotely on ACR (no local Docker needed)
Write-Host "Pushing image on ACR: $ACR_NAME ..."
docker push "${ACR_ENDPOINT}/web:latest"

# Configure the Web App to pull from ACR
Write-Host "Configuring Web App: $WEBAPP_NAME to use image $IMAGE ..."
az webapp config container set `
    --name $WEBAPP_NAME `
    --resource-group $RG `
    --container-image-name $IMAGE `
    --container-registry-url "https://${ACR_ENDPOINT}"

Write-Host "Deployment complete."