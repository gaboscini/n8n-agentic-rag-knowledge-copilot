# Testing

## Repository validation

Run:

~~~powershell
npm.cmd run build
npm.cmd test
~~~

The validator checks workflow and dataset parsing, unique nodes, connections, Code-node syntax, note coverage, node spacing, zero connector crossings across main and AI sub-node paths, connector-length budgets, native AI Agent and integration coverage, inactive status, credential exclusion, Supabase controls, knowledge frontmatter, synthetic datasets, required portfolio files, credential patterns, and public author identity.

## Functional scenarios

1. Current Enterprise SLA with an account-specific override.
2. SAML failure after certificate rotation.
3. Similar-incident retrieval.
4. Superseded SLA exclusion.
5. Restricted-document denial.
6. Document prompt-injection quarantine.
7. User prompt-injection denial.
8. Unsupported guarantee abstention.
9. Refund-authority boundary.
10. Secret-handling response.
11. Ticket-draft approval.
12. Slack escalation approval.
13. Approval expiration or rejection.
14. Low-groundedness human fallback.
15. Integration failure and dead-letter capture.

## Evaluation thresholds

The runtime quality gate requires evaluator approval, permission safety, groundedness of at least 0.82, and citation quality of at least 0.82.

The nightly evaluation lane stores retrieval, groundedness, citation, permission, and tool-selection scores and posts an aggregate quality digest.
