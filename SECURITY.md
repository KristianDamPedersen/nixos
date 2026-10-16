# Security and resilience requirements

## Purpose and scope

This repository is a blueprint for a company-managed NixOS work laptop used
for consultancy, including Danish governmental assignments. The objective is
to give internal IT a transparent, reviewable security baseline and evidence
that the deployed machine meets it.

The scope is use under the consultancy's own IT guarantees. Client-issued
equipment and client-specific acceptance are separate matters. This baseline
does not establish suitability for classified information.

NixOS makes intended configuration explicit, versioned and repeatable. That
transparency supports review and change control; it does not by itself prove
runtime enforcement, resilience or compliance.

## Status and evidence

All requirements below are **proposed for internal IT approval**. Their
implementation and effectiveness have not yet been assessed. Inclusion in
this document is not evidence that a control is implemented.

For each requirement, record:

- Applicable hosts and data, source and rationale.
- Accountable owner and internal IT approval.
- Implementation references and deployed system revision.
- Verification method, dated results and supporting evidence.
- Operational responsibilities and review frequency.
- Exceptions, compensating controls, approver and review or expiry date.

Keep three kinds of evidence distinct: declared configuration, observed
runtime enforcement, and practical test results. Store sensitive evidence in
an approved restricted location; never put secrets or private keys here.

## Requirements register

| ID | Proposed requirement | Evidence for internal IT |
| --- | --- | --- |
| GOV-01 | Maintain an inventory of the device, owner, hardware, OS version and installed software. | Device record and generated software inventory. |
| GOV-02 | Document permitted use, data classifications and responsibilities for managing the laptop. | Approved baseline and responsibility assignment. |
| GOV-03 | Document deviations from the baseline, with an owner and review date. | Exception register. |
| ENC-01 | Encrypt all persistent storage containing company data, including swap and hibernation images where used. | Storage layout, encryption configuration and runtime verification. |
| ENC-02 | Protect encryption recovery material and establish an approved recovery process. | Access-controlled recovery procedure and recovery-test result. |
| IAM-01 | Use individual accounts and separate everyday activity from privileged administration. | Account and privilege configuration; demonstration of elevation controls. |
| IAM-02 | Use strong, unique passwords and approved credential storage. | Password policy and credential-management configuration. |
| IAM-03 | Require MFA for company remote access and privileged services where supported; prefer phishing-resistant methods. | Authentication policy and enrolment evidence. |
| LOCK-01 | Lock automatically after an agreed idle period and before suspend; require authentication on return. | Configuration and practical idle, suspend and resume tests. |
| PATCH-01 | Run supported OS and application versions, with an inventory of update mechanisms. | Release and support record and update coverage report. |
| PATCH-02 | Apply security updates within defined deadlines, with an expedited process for urgent vulnerabilities. | Update history, deadlines and exception handling. |
| PATCH-03 | Ensure updates reach running software, including required service restarts and reboots. | Verification of running versions and pending restart status. |
| BOOT-01 | Protect and verify boot integrity, including an approved Secure Boot design. | Boot configuration, key-management procedure and runtime verification. |
| FW-01 | Maintain firmware and device security updates through a documented process. | Firmware inventory and update records. |
| NET-01 | Enable a host firewall and permit only justified network exposure. | Firewall rules and external port-scan results. |
| NET-02 | Use approved remote-access and DNS protection, with defined behaviour when connectivity fails. | Network policy and VPN and DNS failure tests. |
| END-01 | Provide endpoint protection and detection accepted by internal IT. | Supported tooling, update status and detection and reporting test. |
| HARD-01 | Minimise enabled services and apply documented OS and application hardening. | Service inventory, baseline configuration and verification results. |
| DATA-01 | Keep company data in approved locations and separate it from personal and other-client data. | Data-flow documentation and access controls. |
| DATA-02 | Keep secrets out of Git, Nix expressions, build outputs and the Nix store. | Secret-management design and targeted verification. |
| DATA-03 | Define controls for removable media, peripheral access and data export. | Approved policy and relevant enforcement tests. |
| REC-01 | Back up required data and recovery configuration to approved, protected storage. | Backup scope, access controls and successful backup records. |
| REC-02 | Restore service after loss, corruption or compromise within agreed recovery targets. | Recorded restoration exercise, including required credentials and keys. |
| LOG-01 | Record useful security events with accurate timestamps, appropriate retention and controlled access. | Logging configuration and example event retrieval. |
| INC-01 | Establish procedures for theft, suspected compromise, credential revocation and reporting to IT. | Incident runbook and tabletop exercise. |
| LIFE-01 | Support onboarding, access removal, device reassignment and secure disposal. | Lifecycle procedures and verification checklist. |
| ASSURE-01 | Verify the deployed machine against the approved baseline regularly and after significant changes. | Dated compliance report identifying failures and exceptions. |

## Decisions requiring internal IT agreement

- Permitted data classifications, software and service destinations, including
  repositories, cloud services, AI tools and backup storage.
- Accepted endpoint protection and detection tooling, device management,
  inventory and compliance reporting.
- Update deadlines, urgent vulnerability handling and supported OS lifecycle.
- Administrative access, approval and time limits for elevated privileges.
- Idle-lock duration and authentication and recovery methods.
- Remote-access routing, DNS protection and connectivity failure behaviour.
- Backup scope, offline or isolated copies, recovery time and acceptable data loss.
- Security-event collection, retention, access and incident reporting.

## Danish reference baseline

The Danish state technical minimum requirements are a benchmark for this
internal baseline. They are not automatically all applicable to a
consultancy-owned machine. Record applicability and any contractual
obligations explicitly.

The September 2025 requirements include:

- Firewall rules allowing only necessary inbound and outbound traffic.
- Always-on VPN from external networks, routing internet traffic through the
  authority's infrastructure.
- Full disk encryption and automatically updated endpoint protection.
- Supported OS and applications; updates within 30 days for non-critical
  systems and as quickly as possible before then for critical systems.
- Separation of everyday and administrative accounts, with additional approval
  and time limits where administration is not the primary job function.
- An OS major release or update less than 24 months old.
- MFA for covered internet-accessible authority systems; OTP codes must not
  be delivered by SMS or email.
- Screening authority account passwords against weak or leaked passwords.
- DNSSEC validation and protection against known malicious domains.

The implementation guidance clarifies that client requirements apply
regardless of OS, cover internal network access through VPN, and have scope
exclusions for certain external computers using only web or virtual desktop
access. Automatically updated antivirus meets the minimum endpoint-protection
requirement; internal IT may require more. Classified systems have separate
requirements.

GDPR security obligations require a risk-based selection of technical and
organisational measures and evidence of adequacy, rather than a universal
laptop configuration. NIS 2 applicability must be assessed separately for the
organisation and its activities.

### Sources

- [Danish state technical minimum requirements, updated September 2025](https://admin.sikkerdigital.dk/Media/638931901863386001/De%20tekniske%20minimumskrav%202024%20opdateret%20september%202025.pdf).
- [Implementation guidance, September 2025](https://admin.sikkerdigital.dk/Media/638931901870547002/Vejledning%20til%20de%20tekniske%20minimumskrav%20-%20september%202025.pdf).
- [Current publication page for the state requirements](https://admin.sikkerdigital.dk/myndighed/tekniske-tiltag/tekniske-minimumskrav).
- [Cyberforsvar, der virker](https://samsik.dk/wp-content/uploads/2025/09/vejledning-cyberforsvar-der-virker-2023.pdf), including backup, offline copies and restoration testing.
- [Datatilsynet: protecting personal data](https://www.datatilsynet.dk/regler-og-vejledning/grundlaeggende-begreber/hvordan-beskytter-du-personoplysninger).
- [Datatilsynet: everyday security](https://www.datatilsynet.dk/regler-og-vejledning/gdpr-univers-for-smaa-virksomheder/trin-6-husk-sikkerheden).
- [Datatilsynet: remote work](https://www.datatilsynet.dk/presse-og-nyheder/nyhedsarkiv/2020/mar/gode-raad-om-hjemmearbejde/).
- [SAMSIK: NIS 2 scope and guidance](https://samsik.dk/nis2/).
- [PET: personnel security approval and need to know](https://pet.dk/saadan-bliver-du-sikkerhedsgodkendt).

Recheck the source documents when approving or revising the baseline.
