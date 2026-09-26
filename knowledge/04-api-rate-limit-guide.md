---
document_id: KB-API-LIMITS-2026
title: API Rate Limits and Retry Guidance
version: "2.4"
effective_date: 2026-05-01
department: support
sensitivity: 1
authority: approved_product_documentation
---

# API Rate Limits and Retry Guidance

API limits are calculated per tenant and per rolling minute.

- Starter: 120 requests per minute
- Business: 600 requests per minute
- Enterprise: 2,000 requests per minute

HTTP 429 responses include a **Retry-After** header. Clients must use exponential backoff with jitter and must not retry more than five times for one logical operation. Bulk export endpoints have separate concurrency limits of one, three, and ten active exports for Starter, Business, and Enterprise respectively.

Support must first confirm the customer plan and endpoint. Do not promise a limit increase. Enterprise customers may request a capacity review through their account owner.

