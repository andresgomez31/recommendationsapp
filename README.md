# Recommendations App — Azure Deployment Guide (CLI)

This guide walks through deploying the app to Azure using the **Azure CLI** and **GitHub CLI** only — no portal UI required.

## Prerequisites

- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) installed
- [GitHub CLI](https://cli.github.com/) installed
- An Azure for Students account
- This repo pushed to GitHub

---

## Known Azure for Students Limitations

Before starting, be aware of these subscription-level restrictions:

- **Allowed regions policy**: Azure for Students enforces a policy that restricts resource deployment to a subset of regions. `eastus` is blocked for this subscription — use `canadacentral` instead (confirmed working).
- **MySQL SKU availability**: `Standard_B1ms` (Burstable) is not available in `eastus` for this subscription. Always verify SKU availability before creating the server (see Step 3).
- **Reserved admin usernames**: `admin`, `administrator`, `root`, `guest` are reserved and rejected by Azure MySQL Flexible Server.
- **Password complexity**: Azure MySQL requires a password with at least 8 characters including uppercase, lowercase, a digit, and a special character (e.g. `MyPass#2024`).

---

## Step 1 — Sign in

```bash
az login
gh auth login
```

Confirm you are on the correct subscription:

```bash
az account set --name "Azure for Students"
az account show --query "{Name:name, Sub:id}" -o table
```

---

## Step 2 — Create Resource Group

> Use `canadacentral` — it is confirmed allowed by the subscription policy. Do not use `eastus`.

```bash
az group create --name rg-recommendations --location canadacentral
```

---

## Step 3 — Verify MySQL SKU Availability

Before creating the server, confirm that `Standard_B1ms` is available in your target region:

```bash
az mysql flexible-server list-skus --location canadacentral -o table
```

Look for a row with `Standard_B1ms` and tier `Burstable`. If it is missing, try `westus2` or `eastus2` and update the location in all subsequent steps.

---

## Step 4 — Create MySQL Flexible Server

```bash
az mysql flexible-server create \
  --resource-group rg-recommendations \
  --name <unique-server-name> \
  --location canadacentral \
  --admin-user dbadmin \
  --admin-password "<YourStr0ng#Password>" \
  --sku-name Standard_B1ms \
  --tier Burstable \
  --public-access 0.0.0.0
```

> The server name must be **globally unique** across all Azure accounts (e.g. `rec-db-yourname`).
> Do **not** use `admin` as the username — it is reserved.
> The password must have uppercase, lowercase, a digit, and a special character.

Create the database:

```bash
az mysql flexible-server db create \
  --resource-group rg-recommendations \
  --server-name <unique-server-name> \
  --database-name recommendations_app
```

---

## Step 5 — Create App Service

Create the App Service Plan (Free tier):

```bash
az appservice plan create \
  --name plan-recommendations \
  --resource-group rg-recommendations \
  --location canadacentral \
  --sku F1 \
  --is-linux
```

> The `--location` flag must be specified explicitly and must match the allowed region. Without it the CLI inherits the resource group location, which may still be blocked.
> Student accounts are limited to **one Free (F1) App Service**. If you already have one, reuse it.

Create the Web App (Node.js 20):

```bash
az webapp create \
  --resource-group rg-recommendations \
  --plan plan-recommendations \
  --name <unique-app-name> \
  --runtime "NODE:20-lts"
```

---

## Step 6 — Configure Environment Variables

```bash
az webapp config appsettings set \
  --resource-group rg-recommendations \
  --name <unique-app-name> \
  --settings \
    DB_HOST=<unique-server-name>.mysql.database.azure.com \
    DB_PORT=3306 \
    DB_USER=dbadmin \
    DB_PASSWORD="<YourStr0ng#Password>" \
    DB_NAME=recommendations_app
```

> Never commit these values to your repo. Use environment variables only.

---

## Step 7 — Connect GitHub (Deployment Pipeline)

```bash
az webapp deployment github-actions add \
  --resource-group rg-recommendations \
  --name <unique-app-name> \
  --repo <github-username>/<repo-name> \
  --branch main \
  --login-with-github
```

This creates a GitHub Actions workflow that triggers on every push to `main`:

```
push → build → deploy
```

---

## Step 8 — Wait for Deployment

Monitor the workflow from the terminal:

```bash
gh run list --repo <github-username>/<repo-name>
gh run watch --repo <github-username>/<repo-name>
```

---

## Step 9 — Test Your App

Get the app URL:

```bash
az webapp show \
  --resource-group rg-recommendations \
  --name <unique-app-name> \
  --query defaultHostName -o tsv
```

Test the API:

```bash
# Add a recommendation
curl -s -X POST https://<unique-app-name>.azurewebsites.net/api/recommendations \
  -H "Content-Type: application/json" \
  -d '{"title":"Inception","type":"Movie","genre":"Sci-Fi","year":2010,"comment":"Mind-bending!","rating":5,"image_url":""}'

# List recommendations
curl -s https://<unique-app-name>.azurewebsites.net/api/recommendations | jq .
```

Add at least 3 meaningful recommendations so classmates can fetch from your API.

---

## Step 10 — Test Your Pipeline

Make a visible change (e.g. edit `public/styles.css`), then push:

```bash
git add public/styles.css
git commit -m "Update styles"
git push origin main
```

Watch the pipeline trigger automatically:

```bash
gh run watch --repo <github-username>/<repo-name>
```

---

## Step 11 — Test External Source

From the app UI, open the **External Source** modal and enter another student's app URL:

```
https://<their-app-name>.azurewebsites.net
```

---

## Final Checklist

- [ ] App runs locally (`npm start`)
- [ ] Code is pushed to GitHub
- [ ] No secrets committed to the repo
- [ ] Azure resource group exists in `canadacentral`
- [ ] MySQL Flexible Server is running in `canadacentral`
- [ ] Database `recommendations_app` exists
- [ ] App Service Plan created in `canadacentral`
- [ ] Web App deployed and running
- [ ] App connects to Azure MySQL
- [ ] External source works
- [ ] No CORS errors in browser console

---

## Deliverable

Submit your deployed app URL:

```
https://<unique-app-name>.azurewebsites.net
```
