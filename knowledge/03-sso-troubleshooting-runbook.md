---
document_id: KB-SSO-2026
title: SAML SSO Troubleshooting Runbook
version: "4.1"
effective_date: 2026-06-10
department: support
sensitivity: 2
authority: approved_runbook
---

# SAML SSO Troubleshooting Runbook

Use this runbook when users cannot sign in through SAML SSO.

## Required evidence

Collect the customer key, affected user count, first failure time, identity provider, error code, recent certificate or metadata changes, and whether password login remains available.

## Diagnostic sequence

1. Confirm the customer subscription includes SSO.
2. Check the platform status page for an active authentication incident.
3. Confirm the configured entity ID and ACS URL match the current tenant values.
4. Verify the identity-provider signing certificate has not expired.
5. Compare the NameID format with the configured email claim.
6. Confirm the user email is normalized and belongs to an allowed domain.
7. Review clock skew. Assertions outside the five-minute tolerance are rejected.
8. Use a sanitized SAML trace. Never request passwords, session cookies, private keys, or full production tokens.
9. If multiple tenants are affected, escalate to Platform Authentication.
10. If only one tenant is affected after a certificate change, request rollback or corrected metadata.

## Resolution evidence

Record the error code, confirmed cause, configuration changed, validation result, and customer confirmation. Do not state that SSO is resolved until a customer test succeeds.
