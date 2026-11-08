# Lens modules

Extra questions for specific workload types. Add a module when its trigger matches; a workload can take several. Entries use the format of `questions.md`. Refs point to each vendor's workload guidance (Azure), lens (AWS) or perspective (Google Cloud). The AWS lens contents were not part of our research, so AWS refs name the lens only.

## AI: AI and generative AI workloads

Trigger: the workload trains, fine-tunes, hosts or calls a machine learning model or LLM, including agents and retrieval-augmented generation.
Refs for the module: Az AI workload guidance · AWS Generative AI Lens, Machine Learning Lens, Responsible AI Lens · GCP AI and ML perspective; SEC5 "Use AI securely and responsibly"

### AI-01 Goals and evaluation · core · High
What must the model do, and how is output quality measured?
- Good: task and success criteria defined; evaluation dataset; metrics for quality, groundedness and safety; evaluation runs before each model or prompt change.
- Evidence: evaluation suite and results.
- Refs: GCP AI/ML performance "Establish performance objectives and evaluation methods", AI/ML security "Define clear goals and requirements"

### AI-02 Data for training and grounding · core · High
Which data feeds the model, and is its use permitted and governed?
- Good: sources inventoried with classification and lineage; rights to use confirmed; personal data minimised; grounding data access respects the end user's permissions.
- Evidence: data inventory; lineage.
- Refs: Az AI design areas "training data design", "grounding data design" · GCP AI/ML reliability "Maintain trust and control through data and model governance"

### AI-03 Input and output protection · core · High
How does the workload defend against prompt injection, data leakage and harmful output?
- Good: input validation and content filtering; output filtering; tools and actions the model can call restricted to least privilege; jailbreak and injection tests in the evaluation suite.
- Evidence: filter configuration; red-team results.
- Refs: GCP AI/ML security "Verify and protect inputs", "Monitor, evaluate, and prepare to respond to outputs"

### AI-04 Model lifecycle and MLOps · core · Med
How are models, prompts and their versions deployed, tracked and rolled back?
- Good: models and prompts versioned; automated pipeline with evaluation gates; rollback to a previous version tested.
- Evidence: pipeline; model registry.
- Refs: Az AI design area "MLOps/GenAIOps" · GCP AI/ML OE "Automate the model development lifecycle", AI/ML reliability "Build an automated end-to-end MLOps platform"

### AI-05 AI observability · core · Med
How do you detect drift, quality decline, abuse and runaway cost in production?
- Good: logging of prompts and responses within privacy limits; quality sampling; drift monitoring; token and cost tracking per feature.
- Evidence: AI dashboards.
- Refs: GCP AI/ML OE "Implement observability", AI/ML reliability "Implement holistic AI and ML observability and reliability practices"

### AI-06 Capacity, quotas and cost · core · Med
Can the model endpoint deliver the needed throughput within budget?
- Good: token or GPU quotas known; provisioned throughput or fallback models for critical flows; cost per request modelled; managed or pre-trained models before custom training.
- Evidence: capacity and cost model.
- Refs: GCP AI/ML cost "Define and measure costs and returns", "Use managed services and pre-trained models"

### AI-07 Responsible AI · core · Med
How are fairness, transparency and accountability handled?
- Good: named accountable owner; users told when they interact with AI; explainability where decisions affect people; obligations under the EU AI Act assessed where relevant.
- Evidence: responsible AI assessment.
- Refs: Az AI design area "responsible AI" · AWS Responsible AI Lens · GCP SEC5 governance recommendations

## DATA: Data and analytics platforms

Trigger: the workload is a data platform, warehouse, lakehouse, data pipeline or reporting solution (for example Microsoft Fabric, Databricks, Synapse, BigQuery, Redshift).
Refs for the module: Az Microsoft Fabric workload guidance, Databricks service guide · AWS Data Analytics Lens · GCP (no dedicated perspective)

### DATA-01 Data ownership and governance · core · High
Who owns each dataset, and how are quality, lineage and access governed?
- Good: data owners named; catalogue with lineage; access granted per dataset through groups; sensitivity labels carried from source to report.
- Evidence: catalogue; access model.
- Refs: Az SE:03, Fabric security "isolation boundaries" · AWS Data Analytics Lens

### DATA-02 Isolation and workspaces · core · Med
How are environments, domains and capacities separated?
- Good: separate workspaces or projects per environment and domain; production capacity isolated from development; noisy workloads cannot starve critical reports.
- Evidence: workspace and capacity layout.
- Refs: Az Fabric reliability "constraints and boundaries", Fabric performance "capacity"

### DATA-03 Pipeline reliability · core · High
What happens when a pipeline fails or delivers late or bad data?
- Good: idempotent, restartable loads; data quality checks with alerts; freshness targets per dataset; reprocessing procedure.
- Evidence: pipeline monitoring; data quality rules.
- Refs: Az RE:07, Fabric reliability "where failures happen" · AWS Data Analytics Lens

### DATA-04 Data recovery · core · High
Can you restore data to a point in time and rebuild derived data?
- Good: source data retained or recoverable; point-in-time restore for stores that allow it; derived layers can be rebuilt from code; tested.
- Evidence: recovery runbook; test log.
- Refs: Az Fabric reliability "DR", RE:09 · AWS REL 9

### DATA-05 Capacity and cost · core · Med
How is compute capacity sized, scheduled and paid for?
- Good: capacity sized from measured usage; pause or scale schedules; heavy jobs off-peak; cost per domain or report visible.
- Evidence: capacity metrics; cost report.
- Refs: Az Fabric cost "cost drivers", "environment costs" · AWS Data Analytics Lens

### DATA-06 Deployment of data assets · core · Med
How do pipelines, models and reports move between environments?
- Good: assets in source control; deployment pipelines; no manual edits in production.
- Evidence: deployment pipeline.
- Refs: Az Fabric OE "safe deployment", OE:06

## SAAS: Multitenant SaaS

Trigger: the workload serves several customer organisations from shared infrastructure.
Refs for the module: Az SaaS workload guidance · AWS SaaS Lens · GCP (no dedicated perspective)

### SAAS-01 Tenancy model · core · High
Which components are shared between tenants, and which are dedicated?
- Good: tenancy model per tier (silo, pool, bridge) chosen against isolation, cost and noisy-neighbour risk; documented in an ADR.
- Evidence: tenancy ADR.
- Refs: Az SaaS design area "resource organization" · AWS SaaS Lens

### SAAS-02 Tenant isolation · core · High
How is one tenant's data and access kept from another?
- Good: tenant context enforced at every layer; isolation tested automatically; tenant-aware identity.
- Evidence: isolation tests.
- Refs: Az SaaS design area "IAM", "data" · AWS SaaS Lens

### SAAS-03 Noisy neighbours and limits · core · Med
How do you stop one tenant degrading service for others?
- Good: per-tenant quotas and throttling; monitoring per tenant; ability to move a tenant.
- Evidence: throttling configuration.
- Refs: Az SaaS design area "compute" · AWS SaaS Lens

### SAAS-04 Tenant lifecycle and billing · core · Med
How are tenants onboarded, metered, billed and offboarded?
- Good: automated onboarding; usage metered per tenant; offboarding deletes or returns tenant data.
- Evidence: onboarding automation; metering design.
- Refs: Az SaaS design area "billing and cost management" · AWS SaaS Lens

## FSI: Regulated financial services

Trigger: the workload falls under financial regulation (for example DORA, national supervisor requirements).
Refs for the module: AWS Financial Services Industry Lens · GCP Financial services perspective · Az (no dedicated workload guidance; use mission-critical guidance)

### FSI-01 Regulatory mapping · core · High
Which regulatory requirements apply to resilience, outsourcing and data, and how does the design meet them?
- Good: requirements mapped to controls; cloud provider listed in the register of ICT third-party providers where DORA applies; exit strategy documented.
- Evidence: regulatory mapping; exit plan.
- Refs: GCP FS reliability "Regulatory requirements", FS security "Meet regulatory, compliance, and privacy needs"

### FSI-02 Aggregate availability and DR · core · High
Does the combined availability of all dependencies meet the regulatory and business targets, within data-residency limits?
- Good: aggregate availability calculated; multi-zone as minimum and multi-region where required; DR regions comply with residency rules; DR tested.
- Evidence: availability calculation; DR test results.
- Refs: GCP FS reliability "Understand and manage aggregate availability", "Implement a robust DR strategy"

### FSI-03 Incident management and reporting · core · High
Can the team classify and report major incidents within regulatory deadlines?
- Good: incident classification matches the regulator's criteria; reporting procedure rehearsed.
- Evidence: incident procedure; exercise records.
- Refs: GCP FS OE "Define and test incident management processes"
