# Architecture

## Design objective

This project is a B2B SaaS support and incident-resolution agent. It is optimized for questions where the answer depends on current product documentation, customer entitlement, historical incidents, security policy, and approval authority.

The architecture separates five responsibilities:

1. governed knowledge ingestion;
2. authenticated agent reasoning;
3. deterministic tools and approval-controlled writes;
4. evaluation and knowledge operations;
5. shared failure recovery.

## Why this is agentic

The runtime contains a native n8n AI Agent. Before the agent runs, an OpenAI planner returns a structured plan containing an intent, search query, approved read tools, proposed write tools, customer key, risk level, and clarification decision. Deterministic workflow logic validates the plan against fixed allowlists.

The AI Agent has an OpenAI chat model, a structured output parser, and a Supabase Vector Store connected as its `authorized_knowledge` tool. It can decide when additional retrieval is required and iterate over tool results before producing a cited answer. Customer entitlement and incident lookups are resolved outside the model, and write proposals wait for a separate approval event.

## Retrieval model

Documents are stored in a conventional n8n-compatible Supabase vector table. Metadata carries tenant, document, version, citation, sensitivity, role, department, and status attributes.

Runtime retrieval combines:

- semantic similarity through OpenAI embeddings and Supabase pgvector;
- metadata filtering before generation;
- deterministic role and clearance filtering after retrieval;
- keyword-overlap reranking;
- current-version and quarantine controls;
- a separate groundedness and citation evaluation.

The schema also includes a custom hybrid-search function for teams that want to call vector and PostgreSQL full-text search through an RPC.

## Decision ownership

| Decision | Owner |
| --- | --- |
| Intent and candidate tool plan | OpenAI planner |
| Knowledge-tool invocation and cited answer synthesis | Native n8n AI Agent |
| Tool allowlist and parameter boundaries | Deterministic workflow |
| Knowledge access | Tenant, role, clearance, department, status, and source metadata |
| Final answer quality | Independent OpenAI evaluator plus deterministic thresholds |
| Ticket or Slack write | Human approver |
| SEV-1 final classification | Incident manager |
| Refund approval | Finance Operations |
| Dead-letter replay | Operator |

## Failure model

The n8n instance error workflow can post a bounded event to the module 99 failure-intake webhook. The lane removes likely credential patterns, truncates context, writes a dead-letter event, and alerts Slack. It does not replay an external action automatically. This avoids routing error connectors across every module on the primary canvas.

## Canvas modules

| Module | Responsibility |
| --- | --- |
| 00 | Supabase readiness check |
| 01 | Document validation, quarantine, versioning, embeddings, and indexing |
| 02 | Authorization, planning, tools, RAG, citations, evaluation, and answer delivery |
| 03 | Approval validation and controlled write execution |
| 04 | User feedback capture |
| 05 | Golden-case evaluation and knowledge freshness |
| 99 | Failure intake and dead-letter recovery |
