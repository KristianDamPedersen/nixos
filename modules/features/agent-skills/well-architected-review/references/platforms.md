# Platform tooling

Vendor tools that support the review. Point the team to the tools for its target cloud in the review record's next steps.

## Azure

- **Azure Well-Architected Review**: free self-assessment on Microsoft Learn Assessments, about 60 questions tied to the pillar checklists. Choose "Core Well-Architected Review" for a whole workload. Specialised assessments exist for AI, analytics, Azure AI Search, Azure Virtual Desktop, data services and SaaS. Sign in to save milestones. Results export to CSV, and the WARP scripts (github.com/Azure/WellArchitected-Tools) import them into Azure DevOps or GitHub.
- **Azure Advisor**: recommendations and an Advisor score broken down by pillar. The Well-Architected Review can import Advisor findings for one subscription or resource group.
- **Service guides**: per-service configuration checklists by pillar for about 30 services, including AKS, App Service, Azure SQL Database, Cosmos DB, Databricks, Front Door and Virtual Network.
- **Workload guidance**: AI, Microsoft Fabric, mission-critical, HPC, SaaS and sustainability.
- **Maturity model**: five levels per pillar, added June 2025.
- **Cloud Adoption Framework and Azure landing zones**: platform-level controls that a workload inherits (CTX-06).

## AWS

- **AWS Well-Architected Tool**: free console service holding the 57 framework questions. Marks unanswered best practices as high-risk or medium-risk issues and builds an improvement plan. Supports milestones, review templates, profiles, sharing through AWS Organizations, a Jira connector and an API.
- **Lenses**: up to 20 per workload from the Lens Catalog (for example Serverless, SaaS, Data Analytics, Generative AI, Machine Learning, Financial Services, Container Build, DevOps), plus custom lenses in JSON.
- **AWS Well-Architected Agent (preview, October 2026)**: weekly automated analysis of an AWS environment covering cost, security, resilience and performance. Requires a Business+ or higher support plan.
- **AWS Trusted Advisor**: checks that help answer Tool questions.
- **AWS Well-Architected Partner program**: partners who run reviews.

## Google Cloud

- **Agent skills**: one per pillar in the GitHub repository `google/skills` (`skills/cloud/google-cloud-waf-<pillar>/SKILL.md`), with assessment questions and a validation checklist. This is Google's only review-specific tooling; there is no hosted questionnaire.
- **Active Assist and Recommender**: rightsizing, idle resource, security and sustainability recommendations.
- **Security Command Center**: security posture and threat detection.
- **FinOps hub**, **Carbon Footprint** and the **Region Picker** (cost, latency and carbon by region).
- **Architecture Center blueprints**, such as the enterprise foundations blueprint, with deployable IaC.
