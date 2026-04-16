#!/usr/bin/env bash
# deploy.sh — Azure deployment script for Recommendations App
# Targets Azure for Students subscription (canadacentral region)
#
# Usage:
#   Edit the variables below, then run:
#   chmod +x deploy.sh && ./deploy.sh

set -euo pipefail

# ---------------------------------------------------------------------------
# CONFIGURATION — edit these before running
# ---------------------------------------------------------------------------
LOCATION="mexicocentral"
RESOURCE_GROUP="rg-recommendations"
DB_SERVER_NAME="rec-db-$(whoami)"        # must be globally unique
DB_NAME="recommendations_app"
DB_ADMIN_USER="dbadmin"
DB_ADMIN_PASSWORD="${DB_ADMIN_PASSWORD:-}"  # set via env var (see below)
APP_PLAN_NAME="plan-recommendations"
APP_NAME="rec-app-$(whoami)"             # must be globally unique
GITHUB_REPO="andresgomez31/recommendationsapp"                           # e.g. andresgomez31/recommendationsapp
GITHUB_BRANCH="main"
# ---------------------------------------------------------------------------

# Colours
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
info "Checking prerequisites..."

command -v az  >/dev/null 2>&1 || error "Azure CLI not found. Install it first."
command -v gh  >/dev/null 2>&1 || error "GitHub CLI not found. Install it first."

if [[ -z "$DB_ADMIN_PASSWORD" ]]; then
  echo -n "Enter a strong DB password (uppercase + lowercase + digit + special char): "
  read -rs DB_ADMIN_PASSWORD
  echo
fi

# Validate password complexity (basic check)
if [[ ${#DB_ADMIN_PASSWORD} -lt 8 ]]; then
  error "Password must be at least 8 characters."
fi

if [[ -z "$GITHUB_REPO" ]]; then
  error "Set GITHUB_REPO in this script before running (e.g. andresgomez31/recommendationsapp)."
fi

# ---------------------------------------------------------------------------
# Step 1 — Select subscription
# ---------------------------------------------------------------------------
info "Setting active subscription to 'Azure for Students'..."
az account set --name "Azure for Students"
az account show --query "{Subscription:name, ID:id}" -o table

# ---------------------------------------------------------------------------
# Step 2 — Resource group
# ---------------------------------------------------------------------------
if az group show --name "$RESOURCE_GROUP" &>/dev/null; then
  warn "Resource group '$RESOURCE_GROUP' already exists, skipping creation."
else
  info "Creating resource group '$RESOURCE_GROUP' in '$LOCATION'..."
  az group create \
    --name "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --output table
fi

# ---------------------------------------------------------------------------
# Step 3 — Verify MySQL SKU availability
# ---------------------------------------------------------------------------
info "Checking MySQL availability in '$LOCATION'..."
SKU_COUNT=$(az mysql flexible-server list-skus \
  --location "$LOCATION" \
  --output tsv 2>/dev/null | wc -l)

if [[ "$SKU_COUNT" -eq 0 ]]; then
  error "No MySQL SKUs available in '$LOCATION'. Check a different region."
fi
info "MySQL SKUs found in '$LOCATION' ($SKU_COUNT entries)."
# ---------------------------------------------------------------------------
# Step 4 — MySQL Flexible Server
# ---------------------------------------------------------------------------
if az mysql flexible-server show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DB_SERVER_NAME" &>/dev/null; then
  warn "MySQL server '$DB_SERVER_NAME' already exists, skipping creation."
else
  info "Creating MySQL Flexible Server '$DB_SERVER_NAME'..."
  az mysql flexible-server create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DB_SERVER_NAME" \
    --location "$LOCATION" \
    --admin-user "$DB_ADMIN_USER" \
    --admin-password "$DB_ADMIN_PASSWORD" \
    --sku-name Standard_B1ms \
    --tier Burstable \
    --public-access 0.0.0.0
fi

info "Waiting for server '$DB_SERVER_NAME' to reach Ready state..."
az mysql flexible-server wait \
  --resource-group "$RESOURCE_GROUP" \
  --name "$DB_SERVER_NAME" \
  --custom "userVisibleState=='Ready'" \
  --interval 15 \
  --timeout 300

if az mysql flexible-server db show \
    --resource-group "$RESOURCE_GROUP" \
    --server-name "$DB_SERVER_NAME" \
    --database-name "$DB_NAME" &>/dev/null; then
  warn "Database '$DB_NAME' already exists, skipping creation."
else
  info "Creating database '$DB_NAME'..."
  az mysql flexible-server db create \
    --resource-group "$RESOURCE_GROUP" \
    --server-name "$DB_SERVER_NAME" \
    --database-name "$DB_NAME"
fi

# ---------------------------------------------------------------------------
# Step 5 — App Service Plan
# ---------------------------------------------------------------------------
if az appservice plan show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$APP_PLAN_NAME" &>/dev/null; then
  warn "App Service Plan '$APP_PLAN_NAME' already exists, skipping creation."
else
  info "Creating App Service Plan '$APP_PLAN_NAME' (F1 Free)..."
  az appservice plan create \
    --name "$APP_PLAN_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --sku F1 \
    --is-linux
fi

# ---------------------------------------------------------------------------
# Step 6 — Web App
# ---------------------------------------------------------------------------
if az webapp show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$APP_NAME" &>/dev/null; then
  warn "Web App '$APP_NAME' already exists, skipping creation."
else
  info "Creating Web App '$APP_NAME' (Node 20)..."
  az webapp create \
    --resource-group "$RESOURCE_GROUP" \
    --plan "$APP_PLAN_NAME" \
    --name "$APP_NAME" \
    --runtime "NODE:20-lts"
fi

# ---------------------------------------------------------------------------
# Step 7 — Environment variables
# ---------------------------------------------------------------------------
info "Configuring app environment variables..."
az webapp config appsettings set \
  --resource-group "$RESOURCE_GROUP" \
  --name "$APP_NAME" \
  --settings \
    DB_HOST="${DB_SERVER_NAME}.mysql.database.azure.com" \
    DB_PORT=3306 \
    DB_USER="$DB_ADMIN_USER" \
    DB_PASSWORD="$DB_ADMIN_PASSWORD" \
    DB_NAME="$DB_NAME" \
  --output table

# ---------------------------------------------------------------------------
# Step 8 — GitHub Actions deployment
# ---------------------------------------------------------------------------
info "Connecting GitHub repo '$GITHUB_REPO' to App Service..."
if ! az webapp deployment github-actions add \
    --resource-group "$RESOURCE_GROUP" \
    --name "$APP_NAME" \
    --repo "$GITHUB_REPO" \
    --branch "$GITHUB_BRANCH" \
    --login-with-github; then
  warn "GitHub Actions connection may already be configured or encountered an error. Continuing..."
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
APP_URL=$(az webapp show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$APP_NAME" \
  --query defaultHostName \
  --output tsv)

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN} Deployment complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "  App URL  : ${GREEN}https://${APP_URL}${NC}"
echo -e "  DB Host  : ${GREEN}${DB_SERVER_NAME}.mysql.database.azure.com${NC}"
echo -e "  DB Name  : ${GREEN}${DB_NAME}${NC}"
echo ""
echo "Monitor your pipeline:"
echo "  gh run watch --repo $GITHUB_REPO"
