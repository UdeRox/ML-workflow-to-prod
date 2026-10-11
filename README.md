# MLOps workshop: bank marketing propensity model

An end-to-end MLOps system: versioned data, tracked experiments, a model registry with a
quality gate, a FastAPI service on Azure Container Apps with canary releases, drift
monitoring, and automated retraining.

| Folder | What it holds |
|---|---|
| `src/` | data contract, training, evaluation, quality gate, model registry |
| `app/` | the prediction API |
| `monitoring/` | log export and drift checks |
| `replayer/` | simulated production traffic for the incident drill |
| `infra/` | Azure resources (Bicep) and the bootstrap script |
| `.github/workflows/` | CI, CD, monitoring and retraining |

Common commands: `make test`, `make repro`, `make experiments`, `make serve`.
Follow the instructor build guide for the full setup.

## Deploying the API to Azure

Use the repository's infrastructure-as-code path rather than creating Azure resources
one by one. `infra/main.bicep` defines the Container Apps workload-profile environment,
the API app, Application Insights, Log Analytics, and a managed identity for GitHub
Actions. `infra/bootstrap.sh` registers the required providers, detects an allowed
region, and deploys that Bicep template into `rg-mlops-workshop`.

The existing `.github/workflows/cd.yml` builds the API image and pushes it to GitHub
Container Registry (GHCR), then performs an approved canary deployment. It does not use
Azure Container Registry (ACR). The GHCR package must be public so Container Apps can
pull it without a stored registry password.

### 1. Prepare the model and publish the first image

The production model and its matching MLflow run metadata are stored in DVC, not Git.
After reproducing the pipeline, ensure the updated `dvc.lock`, model, and `run_info.json`
have been pushed to the configured DagsHub remote:
##Test 
```sh
uv run dvc push
```

In GitHub **Settings → Secrets and variables → Actions**, configure:

- Repository variable `DAGSHUB_OWNER`
- Repository secret `DAGSHUB_TOKEN`, with read access to the DVC remote

Run the **CD** workflow from the `main` branch. Its build job downloads the exact model
object referenced by `dvc.lock` from DagsHub, verifies its MD5 checksum, builds the
image, and publishes `ghcr.io/uderox/ml-workflow-to-prod:latest`.
The first deployment job is skipped until the Azure infrastructure exists.

In the GitHub repository's **Packages**, open the
`ml-workflow-to-prod` container package and change its visibility to **Public**. This
allows Azure Container Apps to pull the image that the Bicep deployment starts with.

### 2. Preview and deploy the Azure infrastructure

Sign in to the intended Azure subscription in the Codespace or Azure Cloud Shell:

```sh
az login
az account set --subscription "<student-subscription-id>"
az account show --output table
```

Check that the selected subscription allows the `eastasia` region. First preview the
template. The preview creates the resource group if needed but does not deploy the
resources:

```sh
bash infra/bootstrap.sh UdeRox/ML-workflow-to-prod \
  ghcr.io/uderox/ml-workflow-to-prod:latest eastasia --what-if
```

Review the proposed resources and costs. If they look right, deploy by running the same
command without `--what-if`:

```sh
bash infra/bootstrap.sh UdeRox/ML-workflow-to-prod \
  ghcr.io/uderox/ml-workflow-to-prod:latest eastasia
```

The script creates a separate resource group named `rg-mlops-workshop`; it does not
reuse any manually created resource group. Its outputs include the three
`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, and `AZURE_SUBSCRIPTION_ID` values needed for
GitHub Actions, plus the public API URL.

### 3. Connect GitHub Actions using OIDC

Copy those three outputs into GitHub repository **variables** with the same names. Do
not create a client secret: Bicep configures federated credentials so the workflow
exchanges a short-lived GitHub OIDC token for Azure access.

Create a GitHub Actions environment named `production` under **Settings → Environments**.
Optionally add required reviewers to make production deployment wait for approval. The
CD workflow targets this environment before deploying.

### 4. Deploy and verify

Run the CD workflow again from `main`. It builds a versioned image, starts a new Azure
revision, checks that revision's `/health` endpoint, then sends 10% of traffic to it
before promoting it to 100%. The deployed API is available at the `APP_URL` printed by
the bootstrap script; `/health` reports service status and `/docs` provides the
interactive API.

The template uses scale-to-zero for the Container Apps app, but Log Analytics and
Application Insights can incur charges based on retention and telemetry ingestion.
Review Azure Cost Management and set a budget alert before using this beyond a test.

Data: Bank Marketing dataset, UCI Machine Learning Repository (Moro, Cortez and Rita, 2014),
licensed CC BY 4.0.
