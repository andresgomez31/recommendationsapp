#!/bin/bash
set -e

# 1 — Confirm the right subscription is active
echo "=== 1. Active Subscription ==="
az account show --query "{Subscription:name, ID:id}" -o table

# 2 — Resource group exists in mexicocentral
echo "=== 2. Resource Group ==="
az group show \
  --name "rg-recommendations" \
  --query "{Name:name, Location:location, State:properties.provisioningState}" \
  -o table

# 3 — MySQL Flexible Server exists and is Ready
echo "=== 3. MySQL Flexible Server ==="
az mysql flexible-server show \
  --resource-group "rg-recommendations" \
  --name "rec-db-andresaugom" \
  --query "{Name:name, State:state, SKU:sku.name, Location:location}" \
  -o table

# 4 — Database was created on that server
echo "=== 4. MySQL Database ==="
az mysql flexible-server db show \
  --resource-group "rg-recommendations" \
  --server-name "rec-db-andresaugom" \
  --database-name "recommendations_app" \
  --query "{Database:name, Charset:charset}" \
  -o table

# 5 — App Service Plan exists (F1, Linux)
echo "=== 5. App Service Plan ==="
az appservice plan show \
  --resource-group "rg-recommendations" \
  --name "plan-recommendations" \
  --query "{Name:name, SKU:sku.name, OS:kind, Status:status}" \
  -o table

# 6 — Web App exists and is running Node 20
echo "=== 6. Web App ==="
az webapp show \
  --resource-group "rg-recommendations" \
  --name "rec-app-andresaugom" \
  --query "{Name:name, State:state, URL:defaultHostName, Runtime:siteConfig.linuxFxVersion}" \
  -o table

# 7 — App settings were applied (DB_HOST, DB_PORT, DB_NAME present)
echo "=== 7. App Settings ==="
az webapp config appsettings list \
  --resource-group "rg-recommendations" \
  --name "rec-app-andresaugom" \
  --query "[?name=='DB_HOST' || name=='DB_PORT' || name=='DB_NAME' || name=='DB_USER']" \
  -o table

# 8 — GitHub Actions deployment source is connected
echo "=== 8. Deployment Source ==="
az webapp deployment source show \
  --resource-group "rg-recommendations" \
  --name "rec-app-andresaugom" \
  --query "{RepoURL:repoUrl, Branch:branch, Type:deploymentRollbackEnabled}" \
  -o table
