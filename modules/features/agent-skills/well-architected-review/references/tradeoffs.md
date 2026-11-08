# Tradeoffs

Use this list to name what a decision costs in the other pillars. Sources: the Azure tradeoff pages (revised April 2026), the AWS framework and review guidance, and the tradeoff statements spread across Google's pillars.

## Rules all three vendors agree on

- Security is almost never traded away. Azure: "Workload teams can almost never compromise on security controls." AWS: "Security and operational excellence are generally not traded-off against the other pillars."
- Tradeoffs depend on business context. AWS gives examples: favour cost and sustainability over reliability in development environments, and reliability over cost for mission-critical systems.
- Never aim for 100% availability (Google). Pick a target from a cost-benefit analysis.
- Cost-optimised does not mean cheapest (Azure: "A cost-optimized workload isn't necessarily a low-cost workload").

## Common tensions

| Decision that favours | Usually costs | What to record |
|---|---|---|
| Reliability: more replicas, zones, regions, DR | Cost (duplicate capacity); Operations (more to deploy and monitor); Security (larger surface, DR copies to protect); Performance (replication latency) | Which flows justify it, per REL-01 targets |
| Security: segmentation, inspection, encryption, rotation | Reliability (more dependencies and misconfiguration risk; key rotation can cause failures; DR needs vaults and keys); Cost (premium SKUs, SIEM, log retention); Performance (inspection and encryption latency); Operations (slower changes, harder debugging) | The control, the threat it addresses, and the measured overhead |
| Cost: density, smaller SKUs, fewer environments, less telemetry | Reliability (less redundancy, larger blast radius); Security (shared identities, removed segmentation); Operations (less observability, less testing); Performance (under-provisioning) | Risk accepted, and who accepted it |
| Operational excellence: safe deployment, observability, more environments | Cost (side-by-side deployments, telemetry storage, tooling licences); Security (automation and log sinks add attack surface); Performance (instrumentation overhead) | The deployment and observability level chosen |
| Performance: caching, partitioning, denormalisation, scale-out | Reliability (more components, consistency issues); Security (stale cached authorisation or data, more surface); Cost (peak-sized supply); Operations (harder backups and rotations) | Cache expiry and invalidation rules; partition strategy |
| Modularity and decoupling | Performance (more network hops). Google: "When performance is critical, a more tightly coupled approach might be appropriate." | Where coupling was kept and why |
| Sustainability: high utilisation, fewer resources | Reliability (less spare capacity). Google says sustainability "isn't a trade-off against other core business objectives" but asks to balance redundancy and utilisation in DR. | Utilisation targets versus headroom |
| Region choice | Cost versus latency versus carbon versus residency (Google Region Picker weighs the first three) | The deciding factor |
| Speed to market | Cost. AWS calls lift-and-shift-then-optimise "a reasonable choice". | The date by which optimisation happens |

## Recording a tradeoff

Write each accepted tradeoff in the review record with: the decision, the pillar it favours, the pillars it costs, the risk accepted, who accepted it, and when to revisit it. Raise a decision that is hard to reverse to an ADR.
