# Question bank

One question set for all three clouds, built from the Azure, AWS and Google Cloud Well-Architected Frameworks as of 2026-11-07. Ask each question in its own words, then compare the answer with **Good**. A **Met** status needs the evidence named under **Evidence**.

## Legend

Each entry heading reads `ID Title · depth · risk`.

- **Depth.** `core` questions apply to every workload. `ext` questions apply at Business-critical and Mission-critical tiers, or when the question's trigger applies. SKILL.md defines the tiers.
- **Risk.** The default risk if the answer is a gap: `High`, `Med` or `Low`. Raise or lower it for the workload's context and record the reason.
- **Refs.** Where the topic sits in each framework.
  - `Az`: Azure design-review checklist codes (RE, SE, CO, OE, PE). The OE codes follow the renumbering of early 2026, so OE:09 is testing and OE:10 is automation.
  - `AWS`: AWS question IDs (OPS, SEC, REL, PERF, COST, SUS) from the framework dated 2024-11-06.
  - `GCP`: Google principles, numbered by us in the order Google lists them. Google does not number its principles. The key is at the end of this file.

---

## CTX: Context and requirements

Answer this section first. Later answers depend on it.

### CTX-01 Business outcome and scope · core · High
What business outcome does the workload deliver, and where is its boundary?
- Good: one-paragraph purpose; in-scope and out-of-scope components listed; named business owner.
- Evidence: project charter or design doc section.
- Refs: Az workload definition, RE principle "Design for business requirements" · AWS OPS 1 · GCP REL1

### CTX-02 Users and critical flows · core · High
Who uses the workload, and which user and system flows matter most?
- Good: flows listed and rated on a criticality scale (for example high, medium, low); later reliability, performance and cost decisions refer to this rating.
- Evidence: flow inventory with ratings.
- Refs: Az RE:02, PE:09, CO:09 · AWS OPS 1 · GCP REL1

### CTX-03 Criticality tier · core · High
What does an hour of downtime or a day of lost data cost the business, in money, reputation, safety or regulatory exposure?
- Good: a tier chosen from SKILL.md with the reasoning written down; the business owner agrees with it.
- Evidence: tier and reasoning in the review record.
- Refs: Az RE:04, mission-critical workload guidance · AWS REL 13 · GCP REL2

### CTX-04 Data inventory and classification · core · High
What data does the workload store or process, and how sensitive is each type?
- Good: data types listed with a classification label each; personal data and special-category data flagged; classification drives encryption, access and retention choices.
- Evidence: data inventory with labels.
- Refs: Az SE:03 · AWS SEC 7 · GCP SEC7

### CTX-05 Compliance obligations · core · High
Which laws, standards and contracts apply (for example GDPR, NIS2, DORA, ISO 27001, customer contracts)?
- Good: each obligation named with the controls it requires and who owns evidence.
- Evidence: obligation-to-control mapping.
- Refs: Az SE:01 · AWS SEC 1 · GCP SEC7

### CTX-06 Platform and landing zone · core · Med
Which cloud, regions and landing zone will host the workload, and which controls does the platform team already provide?
- Good: target platform named; inherited controls (network, identity, policy, logging) listed; platform constraints such as region or SKU allowlists known; anything undefined treated as a risk.
- Evidence: landing zone documentation; list of inherited controls.
- Refs: Az workload definition (application landing zones, shared responsibility) · AWS SEC 1 · GCP SEC shared responsibility page

### CTX-07 Budget · core · Med
What budget envelope does the workload have, and who pays for it?
- Good: budget for build and for monthly run cost agreed with the business owner; chargeback or showback model known.
- Evidence: approved budget.
- Refs: Az CO:02 · AWS COST 1 · GCP COST1

### CTX-08 Growth and lifespan · core · Med
How much will usage grow, and how long will the workload live?
- Good: load forecast for 12 to 36 months; expected lifespan or sunset date; the design does not build for growth beyond the forecast.
- Evidence: forecast numbers.
- Refs: Az RE principle "Design for business requirements", PE:02 · AWS PERF 1 · GCP PERF1

### CTX-09 Team and ownership · core · Med
Who builds, who runs and who supports the workload after go-live?
- Good: named owning team; on-call model; skills gaps identified with a plan.
- Evidence: RACI or operating model.
- Refs: Az OE:01 · AWS OPS 2, OPS 3 · GCP OE1

### CTX-10 Constraints and one-way doors · core · Med
Which decisions are already fixed (mandated technology, licences, contracts, deadlines), and which upcoming decisions are hard to reverse?
- Good: constraints listed; each one-way-door decision gets an ADR before it is made.
- Evidence: constraints list; ADRs.
- Refs: AWS review process ("one-way doors") · Az CO:05 (licence portability)

---

## DES: Design foundations

### DES-01 Simplicity and managed services · core · Med
Is every component needed, and does the design use platform features before custom code?
- Good: each custom component has a reason a managed service would not do; critical path kept lean.
- Evidence: component list with build-or-buy reasons.
- Refs: Az RE:01, PE:03, PE:07 · AWS OPS design principle "Use managed services", PERF 1 · GCP core principle "Simplify your design and use fully managed services"

### DES-02 Decoupling and state · core · Med
Can components be deployed, scaled and fail independently, and where does state live?
- Good: components communicate through defined interfaces; stateful components identified; stateless components can be replaced at any time.
- Evidence: architecture diagram marking state.
- Refs: Az RE:07 · AWS REL 3, REL 4 · GCP core principles "Decouple your architecture" and "Use a stateless architecture", PERF3

### DES-03 Service selection against requirements · core · Med
Was each service and tier chosen against the reliability, performance, security and cost targets?
- Good: the chosen tier's SLA, limits and features meet the targets; alternatives considered for major cost or risk drivers; a proof of concept for unknowns.
- Evidence: service selection ADRs.
- Refs: Az PE:03, CO:06 · AWS PERF 1, COST 5 · GCP COST3

### DES-04 Architecture documentation · core · Low
Is the architecture documented well enough for a new team member to operate and change it?
- Good: current diagram; ADRs for significant decisions, including tradeoffs; change history.
- Evidence: docs in the repository.
- Refs: Az OE:04 · AWS OPS 1 (tradeoff evaluation) · GCP core principle "Document your architecture"

---

## REL: Reliability

### REL-01 Reliability and recovery targets · core · High
What are the availability target (SLO), recovery time objective (RTO) and recovery point objective (RPO) for each critical flow?
- Good: numeric targets per flow; composite availability of dependencies calculated and compatible with the targets; targets below 100%.
- Evidence: targets table; composite SLA calculation.
- Refs: Az RE:04 · AWS REL 13 · GCP REL1, REL2

### REL-02 Failure mode analysis · core · High
What can fail in each critical flow, including external dependencies, and what happens when it does?
- Good: failure modes per component, including identity, DNS, third-party APIs and the platform; blast radius known; mitigation or accepted risk for each.
- Evidence: failure mode analysis table.
- Refs: Az RE:03 · AWS REL 10, REL 11 · GCP REL3

### REL-03 Redundancy · core · High
Where is redundancy built in, and does it match the targets in REL-01?
- Good: no single point of failure on critical flows; zone redundancy as the default for production; multi-region only where targets require it.
- Evidence: deployment topology.
- Refs: Az RE:05 · AWS REL 10, REL 11 · GCP REL3

### REL-04 Resilience patterns · core · High
How does the workload handle transient faults, overload and partial failure?
- Good: retries with backoff and jitter, timeouts, circuit breakers, idempotent operations, throttling and load shedding, dead-letter queues; noncritical features degrade before critical ones.
- Evidence: code or configuration showing the patterns.
- Refs: Az RE:07 · AWS REL 4, REL 5 · GCP REL6

### REL-05 Backup and restore · core · High
What is backed up, how often, where, and when was a restore last tested?
- Good: every stateful component covered; frequency meets RPO; backups immutable and isolated from production credentials; restores tested on a schedule.
- Evidence: backup policy; restore test log.
- Refs: Az RE:09, SE principle "Design to protect integrity" · AWS REL 9 · GCP REL8

### REL-06 Disaster recovery plan · core · High
How does the workload recover from losing a zone, a region or the primary data store, and has that been rehearsed?
- Good: DR strategy chosen to meet RTO and RPO (backup and restore, pilot light, warm standby or active-active); documented runbook; drills on a schedule; security controls included in the DR environment.
- Evidence: DR plan; drill results.
- Refs: Az RE:09 · AWS REL 13 · GCP REL7

### REL-07 Health model and reliability monitoring · core · High
How do you know a critical flow is unhealthy before users report it?
- Good: health model per flow with healthy, degraded and unhealthy states; alerts on SLO burn, not on every metric; health data retained for post-incident analysis.
- Evidence: health model; alert rules.
- Refs: Az RE:10 · AWS REL 6 · GCP REL5

### REL-08 Quotas and capacity availability · ext · Med
Which quotas, service limits and regional capacity constraints could block scaling or recovery?
- Good: limits for each service known and monitored; quota increases requested before launch; capacity reserved where recovery depends on it.
- Evidence: quota inventory.
- Refs: Az capacity resilience design guide · AWS REL 1 · GCP PERF1

### REL-09 Network topology · ext · Med
Is the network design resilient and sized for growth?
- Good: IP ranges planned without overlap; redundant hybrid connectivity where on-premises is a dependency; DNS failure considered.
- Evidence: network diagram; IP plan.
- Refs: Az RE:05, SE:06 · AWS REL 2 · GCP SEC2

### REL-10 Reliability testing · ext · Med
How do you prove the workload withstands faults and recovers within targets?
- Good: fault injection or chaos experiments in pre-production, and in production for mission-critical workloads; results feed back into the design.
- Evidence: test plan; experiment results.
- Refs: Az RE:08 · AWS REL 12 · GCP REL7

---

## SEC: Security

### SEC-01 Security baseline · core · High
Which security baseline does the workload follow, and how is drift measured?
- Good: baseline derived from compliance obligations and platform benchmarks (for example Microsoft cloud security benchmark, CIS); posture management tool scores the workload continuously.
- Evidence: baseline document; posture score.
- Refs: Az SE:01 · AWS SEC 1 · GCP SEC1, SEC7

### SEC-02 Threat model · core · High
What threats does the design face, and which controls address them?
- Good: threat model (for example STRIDE) covering every trust boundary; mitigations tracked in the backlog; model updated with significant design changes.
- Evidence: threat model document.
- Refs: Az SE:02 · AWS SEC 1, SEC 11 · GCP SEC1

### SEC-03 Human identity and access · core · High
How do people authenticate and get access to the workload and its management plane?
- Good: central identity provider with SSO and MFA; conditional access; least privilege with just-in-time elevation for admin roles; regular access reviews; emergency access accounts controlled and audited.
- Evidence: role assignments; access review records.
- Refs: Az SE:05 · AWS SEC 2, SEC 3 · GCP SEC2

### SEC-04 Workload identity · core · High
How do services authenticate to each other and to cloud resources?
- Good: managed or federated workload identities; no long-lived keys or passwords in code or configuration; permissions scoped per component.
- Evidence: identity configuration in IaC.
- Refs: Az SE:05 · AWS SEC 2, SEC 3 · GCP SEC2

### SEC-05 Segmentation and network controls · core · High
How is the workload segmented, and how is inbound and outbound traffic filtered?
- Good: segmentation across network, identity and resource organization; private endpoints for platform services; ingress through a web application firewall; egress restricted to known destinations; DDoS protection on public endpoints.
- Evidence: network diagram with controls; firewall rules.
- Refs: Az SE:04, SE:06 · AWS SEC 5 · GCP SEC2

### SEC-06 Encryption and data protection · core · High
How is data protected at rest, in transit and against exfiltration?
- Good: encryption at rest and TLS 1.2 or later everywhere; customer-managed keys where classification or regulation requires them; exfiltration controls on sensitive stores.
- Evidence: encryption configuration; key management design.
- Refs: Az SE:07 · AWS SEC 8, SEC 9 · GCP SEC1, SEC2

### SEC-07 Secrets management · core · High
Where are secrets, keys and certificates stored, and how are they rotated?
- Good: a managed vault; access audited; automatic rotation; an emergency rotation procedure that has been tested.
- Evidence: vault configuration; rotation log.
- Refs: Az SE:09 · AWS SEC 2 · GCP SEC1

### SEC-08 Hardening and vulnerability management · core · Med
How are components hardened and patched?
- Good: unused features and ports disabled; hardened base images; vulnerability scanning of running resources; patch windows with defined deadlines by severity.
- Evidence: scan results; patch policy.
- Refs: Az SE:08 · AWS SEC 6 · GCP SEC1, SEC3

### SEC-09 Secure development and supply chain · core · High
How are security checks built into development and the build pipeline?
- Good: static analysis, dependency and secret scanning, and container scanning in CI; signed artifacts; pipeline identities with least privilege; developers trained on secure coding.
- Evidence: pipeline definitions showing the checks.
- Refs: Az SE:02, OE:06 · AWS SEC 11 · GCP SEC3

### SEC-10 Security monitoring and detection · core · High
Which security events are logged, and who sees the alerts?
- Good: audit and security logs centralized; integration with the organization's SIEM and SOC; alerts with an owner and a triage path.
- Evidence: log routing configuration; alert rules.
- Refs: Az SE:10 · AWS SEC 4 · GCP SEC4

### SEC-11 Security incident response · core · High
What happens when a security incident hits this workload?
- Good: playbooks for likely incidents; named responders; aligned with the central SOC; regulatory notification deadlines known (for example GDPR's 72-hour breach notification); playbooks exercised.
- Evidence: playbooks; exercise records.
- Refs: Az SE:12 · AWS SEC 10 · GCP SEC4

### SEC-12 Privacy and data lifecycle · core · High
How does the workload minimise, locate, retain and delete personal data?
- Good: only needed personal data collected; residency meets obligations; retention periods defined and enforced; deletion and data-subject requests supported.
- Evidence: retention policy; residency configuration.
- Trigger: personal data present (CTX-04). Otherwise mark N/A.
- Refs: Az SE:03 · AWS SEC 7 · GCP SEC7

### SEC-13 Security testing · ext · Med
How are security controls and detections tested?
- Good: penetration test before go-live and on a schedule; detections validated with simulated attacks; findings tracked to closure.
- Evidence: test reports.
- Refs: Az SE:11 · AWS SEC 11 · GCP SEC4

---

## OPS: Operational excellence

### OPS-01 Operating model and standards · core · Med
Which standard practices does the team follow to build and run the workload?
- Good: documented standards for routine, ad hoc and emergency operations; blameless culture; standards reviewed on a cadence.
- Evidence: team working agreement or runbook index.
- Refs: Az OE:01, OE:02 · AWS OPS 2, OPS 3 · GCP OE1

### OPS-02 Development practices · core · Med
How is work planned, coded and reviewed?
- Good: shared backlog; source control with a branching strategy; code review on every change; style guides and a common toolchain.
- Evidence: repository settings; branch policies.
- Refs: Az OE:03, OE:04 · AWS OPS 5 · GCP OE4

### OPS-03 Infrastructure as code · core · High
Is all infrastructure and configuration defined as code?
- Good: every environment deployed from IaC; declarative where practical; modules reused; no manual changes in production, and drift is detected.
- Evidence: IaC in the repository.
- Refs: Az OE:05 · AWS OPS 5 · GCP OE4

### OPS-04 Delivery pipeline · core · High
How do changes move from commit to production?
- Good: automated pipelines for code, infrastructure and configuration; immutable artifacts promoted through environments; quality gates at each stage.
- Evidence: pipeline definitions.
- Refs: Az OE:06 · AWS OPS 5, OPS 6 · GCP OE4

### OPS-05 Testing strategy · core · Med
Which tests run, when, and what must pass before release?
- Good: unit, integration and end-to-end tests tied to business risk; tests run in the pipeline; failing tests block release.
- Evidence: test reports in the pipeline.
- Refs: Az OE:09 · AWS OPS 5 · GCP OE4

### OPS-06 Safe deployment · core · High
How do you limit the impact of a bad release, and how fast can you roll back?
- Good: small, frequent releases; progressive exposure (rings, canary, blue-green or feature flags); automated rollback or roll forward; an emergency change path agreed in advance; safe decommissioning.
- Evidence: deployment strategy; rollback test.
- Refs: Az OE:11 · AWS OPS 6, REL 8 · GCP OE4

### OPS-07 Observability · core · High
Can the team see what the workload is doing across infrastructure and code?
- Good: logs, metrics and traces collected consistently and correlated by request; dashboards for each audience; only actionable alerts; retention set per data type.
- Evidence: monitoring configuration; dashboards.
- Refs: Az OE:07 · AWS OPS 4, OPS 8 · GCP OE1, REL5

### OPS-08 Incident management · core · High
How are incidents detected, handled and learned from?
- Good: on-call rotation; severity levels; runbooks for known failures; communication plan; blameless postmortems with tracked actions.
- Evidence: incident process; postmortem examples.
- Refs: Az OE:08 · AWS OPS 10, OPS 11 · GCP OE2, REL9

### OPS-09 Operational readiness · core · Med
What must be true before the workload goes live?
- Good: a go-live checklist covering runbooks, monitoring, support handover, access and backups; sign-off by the operating team.
- Evidence: completed readiness checklist.
- Refs: Az OE:02 · AWS OPS 7 · GCP OE1

### OPS-10 Automation · ext · Low
Which repetitive operational tasks are automated, and how is the automation itself kept safe?
- Good: automation chosen where return on investment is clear; automation treated as a critical dependency with its own security and reliability controls.
- Evidence: automation inventory.
- Refs: Az OE:10 · AWS OPS design principle "Safely automate where possible" · GCP OE4

### OPS-11 Continuous improvement · ext · Low
How does the workload improve after go-live?
- Good: operational KPIs reviewed on a cadence; retrospectives; this review repeated at milestones and after major changes.
- Evidence: KPI dashboard; review history.
- Refs: Az OE:01 · AWS OPS 9, OPS 11 · GCP OE5

---

## PERF: Performance efficiency

### PERF-01 Performance targets · core · High
What numeric performance targets apply to each critical flow?
- Good: latency percentiles (for example p95), throughput and tolerance ranges per flow, agreed with the business owner.
- Evidence: targets table.
- Refs: Az PE:01, PE:09 · AWS PERF 1 · GCP PERF4

### PERF-02 Capacity planning · core · Med
What load must the workload handle at normal and peak times?
- Good: load model with peak events (seasonal, campaigns, month-end); capacity planned before predicted changes.
- Evidence: load model.
- Refs: Az PE:02 · AWS PERF 2, COST 9 · GCP PERF1, PERF2

### PERF-03 Scaling and partitioning · core · High
How does each tier scale, and what limits the scaling?
- Good: autoscaling based on load signals with tested minimums and maximums; scale units defined; partitioning for data that outgrows one node; scaling limits known.
- Evidence: scaling configuration.
- Refs: Az PE:05, RE:06 · AWS REL 7, PERF 2 · GCP PERF2, REL4

### PERF-04 Data performance · core · Med
Are data stores, partitions, indexes and caches designed for the actual access patterns?
- Good: store chosen per access pattern; partition keys and indexes match the main queries; caching with defined invalidation and expiry.
- Evidence: data design notes.
- Refs: Az PE:08 · AWS PERF 3 · GCP PERF3

### PERF-05 Performance testing · core · Med
How do you prove the workload meets its performance targets?
- Good: load tests in a production-like environment before go-live; performance tests as a quality gate for significant changes.
- Evidence: load test results.
- Refs: Az PE:06 · AWS PERF 5, REL 12 · GCP REL6, PERF4

### PERF-06 Network and latency · ext · Med
Is the workload placed and connected to keep latency within targets?
- Good: regions close to users and data; CDN for static content; private connectivity sized for throughput.
- Evidence: latency measurements.
- Refs: Az PE:03, PE:07 · AWS PERF 4 · GCP PERF1

### PERF-07 Performance monitoring and regression · ext · Med
How do you detect performance degradation over time, including degradation caused by routine operations?
- Good: baselines and trend monitoring; alerts on regression; the effect of backups, reindexing, scans and deployments measured; a process for live performance issues.
- Evidence: performance dashboards.
- Refs: Az PE:04, PE:10, PE:11, PE:12 · AWS PERF 5 · GCP PERF4

---

## COST: Cost optimization

### COST-01 Cost model · core · High
What will the workload cost to build and to run, per environment?
- Good: estimate of initial and monthly run cost per environment, with a buffer for unplanned spend; major cost drivers identified.
- Evidence: cost estimate (for example from the provider's pricing calculator).
- Refs: Az CO:02 · AWS COST 1 · GCP COST1, COST3

### COST-02 Cost accountability and allocation · core · Med
Who owns the spend, and can costs be attributed to this workload?
- Good: named cost owner; consistent tags or labels on every resource; showback or chargeback in place.
- Evidence: tagging policy; cost report filtered by workload.
- Refs: Az CO:01, CO:03 · AWS COST 1, COST 2, COST 3 · GCP COST2

### COST-03 Cost monitoring · core · High
How will you notice unexpected spend?
- Good: budgets with alerts at thresholds; anomaly detection; regular reviews of actual spend against the model.
- Evidence: budget and alert configuration.
- Refs: Az CO:03 · AWS COST 3 · GCP COST2, COST4

### COST-04 Spending guardrails · core · Med
Which controls prevent expensive mistakes?
- Good: policies restricting SKUs and regions; resource limits; approval gates for costly changes; automated rather than manual controls.
- Evidence: policy assignments.
- Refs: Az CO:04 · AWS COST 2 · GCP COST3

### COST-05 Right-sizing and component costs · core · Med
Is each component sized to its measured need, and is each cost aligned with the priority of the flow it serves?
- Good: sizing based on measured or modelled load; low-priority flows on cheaper resources; unneeded features and resources removed.
- Evidence: sizing rationale.
- Refs: Az CO:07, CO:09, CO:11 · AWS COST 5, COST 6 · GCP COST3

### COST-06 Environment costs · core · Med
How many environments exist, and how is non-production spend controlled?
- Good: only needed environments; non-production on smaller SKUs, scheduled shutdown or ephemeral; non-production still emulates production where it matters.
- Evidence: environment list with sizing.
- Refs: Az CO:08 · AWS COST 6 · GCP COST3

### COST-07 Data and transfer costs · core · Med
What do storage, replication and data transfer cost, and how is that controlled?
- Good: egress and cross-region traffic estimated; storage tiering and lifecycle rules; retention aligned with data priority.
- Evidence: data lifecycle policy.
- Refs: Az CO:10 · AWS COST 8 · GCP COST3, COST4

### COST-08 Pricing models and rates · ext · Med
Are you paying the best available rate?
- Good: commitments (reservations, savings plans, committed use discounts) for stable usage; licence benefits used; consumption pricing for variable load.
- Evidence: rate review.
- Refs: Az CO:05, CO:06 · AWS COST 7 · GCP COST2

### COST-09 Demand and supply alignment · ext · Low
Does capacity follow demand?
- Good: scale-in configured; batch work scheduled to off-peak or cheaper capacity; queues smooth spikes.
- Evidence: scaling and scheduling configuration.
- Refs: Az CO:12 · AWS COST 9 · GCP COST3

### COST-10 Optimisation over time · ext · Low
How are unused resources found and removed, and how are new services evaluated?
- Good: scheduled cost reviews; provider recommendations acted on; decommissioning process; consolidation where density helps.
- Evidence: review log.
- Refs: Az CO:07, CO:14 · AWS COST 4, COST 10 · GCP COST4

### COST-11 Cost of effort · ext · Low
Does the design account for the cost of people's time, not only cloud spend?
- Good: build-versus-buy decisions include engineering and operations effort; total cost of ownership considered; toil measured.
- Evidence: TCO note in ADRs.
- Refs: Az CO:13 · AWS COST 11 · GCP COST1

---

## SUS: Sustainability

Trigger: the organization has sustainability targets or reporting obligations (for example CSRD), or the tier is Business-critical or higher. Azure treats sustainability as cross-pillar guidance without checklist codes, so Azure refs point to its sustainability recommendations.

### SUS-01 Region and timing · ext · Low
Were regions and batch schedules chosen with carbon intensity as one factor?
- Good: carbon intensity weighed alongside latency, cost and compliance; flexible batch work scheduled at lower-carbon times.
- Evidence: region decision ADR.
- Refs: Az sustainability "Use geography and timing deliberately" · AWS SUS 1 · GCP SUS1

### SUS-02 Utilisation · ext · Low
Does provisioned capacity follow demand, with little idle capacity?
- Good: scale to zero where possible; high utilisation targets; idle resources removed.
- Evidence: utilisation metrics.
- Refs: Az sustainability "Reduce idle and baseline platform waste" · AWS SUS 2 · GCP SUS3

### SUS-03 Efficient software and architecture · ext · Low
Is the code and architecture efficient in compute and network use?
- Good: asynchronous and batch processing where latency allows; efficient algorithms; reduced network traversal; frontend payloads optimised.
- Evidence: profiling results.
- Refs: Az sustainability "Improve application efficiency" · AWS SUS 3 · GCP SUS4

### SUS-04 Data footprint · ext · Low
Does the workload keep only data with ongoing value?
- Good: retention limits; cold data tiered or deleted; data movement minimised.
- Evidence: lifecycle rules.
- Refs: Az sustainability "Control storage growth over time" · AWS SUS 4 · GCP SUS5

### SUS-05 Hardware and services · ext · Low
Are efficient instance types and managed services used?
- Good: current-generation or ARM-based instances where supported; managed services with shared infrastructure; accelerators sized to the work.
- Evidence: SKU choices.
- Refs: Az sustainability "Optimize compute resources" · AWS SUS 5 · GCP SUS2, SUS3

### SUS-06 Measurement and goals · ext · Low
How is the workload's carbon footprint measured and reported?
- Good: provider carbon reporting enabled; workload-level baseline; targets linked to organizational goals.
- Evidence: carbon report.
- Refs: Az sustainability "Monitor and measure sustainability" · AWS SUS 6 · GCP SUS6, SUS7, SUS8

---

## Key to GCP refs

Our numbering, in the order Google lists the principles in each pillar.

| Ref | Google principle |
|---|---|
| OE1 | Ensure operational readiness and performance using CloudOps |
| OE2 | Manage incidents and problems |
| OE3 | Manage and optimize cloud resources |
| OE4 | Automate and manage change |
| OE5 | Continuously improve and innovate |
| SEC1 | Implement security by design |
| SEC2 | Implement zero trust |
| SEC3 | Implement shift-left security |
| SEC4 | Implement preemptive cyber defense |
| SEC5 | Use AI securely and responsibly |
| SEC6 | Use AI for security |
| SEC7 | Meet regulatory, compliance, and privacy needs |
| REL1 | Define reliability based on user-experience goals |
| REL2 | Set realistic targets for reliability |
| REL3 | Build highly available systems through resource redundancy |
| REL4 | Take advantage of horizontal scalability |
| REL5 | Detect potential failures by using observability |
| REL6 | Design for graceful degradation |
| REL7 | Perform testing for recovery from failures |
| REL8 | Perform testing for recovery from data loss |
| REL9 | Conduct thorough postmortems |
| COST1 | Align cloud spending with business value |
| COST2 | Foster a culture of cost awareness |
| COST3 | Optimize resource usage |
| COST4 | Optimize continuously |
| PERF1 | Plan resource allocation |
| PERF2 | Take advantage of elasticity |
| PERF3 | Promote modular design |
| PERF4 | Continuously monitor and improve performance |
| SUS1 | Use regions that consume low-carbon energy |
| SUS2 | Optimize AI and ML workloads for energy efficiency |
| SUS3 | Optimize resource usage for sustainability |
| SUS4 | Develop energy-efficient software |
| SUS5 | Optimize data and storage for sustainability |
| SUS6 | Continuously measure and improve sustainability |
| SUS7 | Promote a culture of sustainability |
| SUS8 | Align sustainability practices with industry guidelines |
