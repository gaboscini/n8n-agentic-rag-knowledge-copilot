# Setup

## Requirements

- n8n with the native OpenAI, Supabase Vector Store, Supabase, and Slack nodes
- Supabase with PostgreSQL and the pgvector extension
- OpenAI access to **gpt-5-mini** and **text-embedding-3-small**, or configured replacements
- A private Slack test channel

Use non-production accounts and synthetic data during setup.

## 1. Prepare Supabase

1. Create a Supabase project.
2. Run **supabase/schema.sql**.
3. Run **supabase/seed.sql**.
4. Confirm the vector extension and governed tables exist.
5. Confirm row-level security is enabled.
6. Replace the demonstration identity assumptions with policies tied to your authentication model.

## 2. Import the workflow

Import **workflows/enterprise-agentic-rag-support-control-plane.json** into n8n.

The workflow is inactive by design. It contains multiple webhooks, schedules, a manual platform check, a native AI Agent with a Supabase knowledge tool, approval controls, and a bounded failure-intake lane.

## 3. Configure credentials

Assign credentials inside n8n:

| Credential | Nodes |
| --- | --- |
| Supabase | All standard Supabase nodes and all three Supabase Vector Store nodes |
| OpenAI | Three structured-response nodes, the AI Agent chat model, and three embedding nodes |
| Slack | Human fallback, approval, execution, evaluation, drift, and incident notifications |

Do not edit credentials into the JSON export.

Confirm that **02.30 - Native RAG Resolution Agent** shows these attached sub-nodes after import:

- **02.30a - OpenAI Agent Chat Model**;
- **02.30b - Authorized Supabase Knowledge Tool**;
- **02.30d - Cited Answer Output Parser**.

The knowledge tool must show **02.30c - OpenAI Agent Tool Embeddings** on its embedding input.

## 4. Configure Slack

Replace **REPLACE_WITH_SLACK_CHANNEL_ID** in every Slack node with a private test channel. Keep approval and operational alerts separate in a production adaptation.

## 5. Index the synthetic knowledge

Execute the knowledge-ingestion webhook once per Markdown file under **knowledge/**.

Use:

- tenant ID: **10000000-0000-4000-8000-000000000001**;
- approved source ID: **30000000-0000-4000-8000-000000000001**;
- customer-upload source ID: **30000000-0000-4000-8000-000000000002** for the intentional prompt-injection example.

The request body must include tenant ID, source ID, external document ID, title, version, content, sensitivity, and allowed roles. The workflow generates embeddings and indexes the chunks.

## 6. Run the platform check

Execute **00 - Manual Platform Check**. Confirm the tenant loads and the audit event is created.

## 7. Test the agent

Call:

**POST /webhook-test/agentic-rag-support-agent**

~~~json
{
  "tenantKey": "saas-support-demo",
  "externalUserId": "agent-104",
  "customerKey": "CUS-ACME-001",
  "question": "All Acme users receive a SAML signature error after certificate rotation. What should we check and what SLA applies?",
  "requestedAction": "prepare_incident_escalation"
}
~~~

Reuse the returned **conversationId** for follow-up questions.

## 8. Test approval

Post the returned approval ID to:

**POST /webhook-test/agentic-rag-action-approval**

~~~json
{
  "tenantId": "10000000-0000-4000-8000-000000000001",
  "approvalId": "RETURNED_APPROVAL_ID",
  "approverExternalId": "incident-manager-22",
  "decision": "approved",
  "reason": "Severity and evidence confirmed"
}
~~~

## 9. Activate safely

Before switching to production webhook URLs, add authenticated ingress, source signatures, request limits, tenant authorization, production RLS policies, retention, monitoring, and backup controls described in **SECURITY.md**. Configure an n8n instance error workflow to send bounded failure events to **POST /webhook/agentic-rag-failure-intake**.
