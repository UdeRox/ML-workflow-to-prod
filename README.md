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

Data: Bank Marketing dataset, UCI Machine Learning Repository (Moro, Cortez and Rita, 2014),
licensed CC BY 4.0.
