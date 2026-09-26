# Security policy

## Reporting a vulnerability

Use GitHub private vulnerability reporting after the repository is public. Do not open a public issue containing credentials, tokens, customer information, private endpoints, prompt-injection payloads, or reproducible exploit details.

Include the affected workflow node or file, prerequisites, impact, a synthetic reproduction, and a recommended remediation when available.

## Security model

This portfolio uses synthetic SaaS data and excludes service credentials. Its controls include tenant-scoped records, role-aware retrieval, source metadata, prompt-injection screening, evidence-based answering, approval-gated write actions, bounded tool inputs, audit events, and dead-letter recovery.

Before deployment, configure and verify:

- authenticated webhook ingress and per-tenant authorization;
- Supabase row-level-security policies for the actual identity provider;
- least-privilege n8n credentials and credential rotation;
- rate limits, replay protection, request-size limits, and abuse monitoring;
- retention and deletion rules for documents, tickets, conversations, embeddings, and audit events;
- document malware scanning and trusted-source allowlists;
- environment-specific model, data-residency, and privacy requirements;
- monitoring, backup, recovery, and incident ownership;
- approval policies for every external write action.

Never commit production documents, customer data, database keys, OAuth tokens, webhook secrets, or n8n credential exports.

