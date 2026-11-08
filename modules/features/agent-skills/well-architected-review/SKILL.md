---
name: well-architected-review
description: Well-Architected design review for a cloud workload on Azure, AWS or Google Cloud, using one question bank that combines the three vendor frameworks. Use when designing a new project or workload, reviewing a solution architecture, checking go-live readiness, or re-reviewing after a major change.
---

# Well-Architected review

Walk a workload through a single question bank built from the Azure, AWS and Google Cloud Well-Architected Frameworks, and produce a **review record**: answers with evidence, a ranked risk register and the accepted tradeoffs.

A review is a conversation, not an audit. It records the current state; a plan in the backlog counts as a **gap** until it is built.

## Steps

### 1. Gather evidence

Read what exists before asking anything: design docs, ADRs, diagrams, IaC, pipeline definitions, README files. Note which questions the material already answers.

Done when every design document and IaC folder in the repository has been read, or the user confirms there is none.

### 2. Establish context

Work through the `CTX` section of [references/questions.md](references/questions.md). Ask the user only for what step 1 did not answer, in batches of three to five questions.

Then set the **criticality tier** with the user:

| Tier | Meaning | Depth |
|---|---|---|
| Standard | Downtime or data loss is an inconvenience; internal tools, proofs of concept | `core` questions |
| Business-critical | Downtime or data loss costs significant money or reputation | `core` and `ext` questions |
| Mission-critical | Failure causes major financial loss, regulatory breach or harm to people | All questions; every **Met** needs linked evidence |

Add each lens module from [references/lenses.md](references/lenses.md) whose trigger matches: AI, DATA, SAAS, FSI.

Done when every CTX question has an answer, the tier is agreed with the user, and the lens modules are chosen.

### 3. Walk the pillars

Go through DES, REL, SEC, OPS, PERF, COST and SUS in that order, then the chosen lens modules. For each question in scope:

1. Answer from the evidence where you can, and show the user your answer for confirmation.
2. Ask the user for the rest, in batches of three to five.
3. Give each question one status:
   - **Met**: matches **Good**, with evidence.
   - **Partial**: some of **Good** is in place.
   - **Gap**: missing, or planned but not built.
   - **Unknown**: nobody present can answer.
   - **N/A**: does not apply. Write the reason.
4. Adjust the default risk when the context justifies it, and note why.

When an answer reveals a decision that favours one pillar at another's expense, record it as a tradeoff using [references/tradeoffs.md](references/tradeoffs.md).

Done when every in-scope question has a status, and every N/A has a reason.

### 4. Write the review record

Copy [templates/review-record.md](templates/review-record.md) to `docs/architecture/well-architected-review-<YYYY-MM-DD>.md`, or to the path the user names, and fill it in:

- Every Gap, Partial and Unknown goes in the risk register with an action. Sort by risk, High first.
- Ask the user for an owner and due date for each High risk.
- Add the vendor tools for the target cloud from [references/platforms.md](references/platforms.md) to the next steps.
- List the ADRs needed for one-way-door decisions and accepted tradeoffs.

Done when the file is written, the summary counts match the answers table, and every High risk has an owner or is marked "owner needed".

### 5. Report

Tell the user the file path, the counts by status, the High risks, and the decisions they still need to make.

## Re-reviews

When a previous review record exists, start from it. Re-ask only questions whose status was not Met, plus questions touched by changes since that review. Keep the earlier record and write a new dated file.
