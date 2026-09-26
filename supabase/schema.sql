-- B2B SaaS Support and Incident Resolution Agent
-- Run in a dedicated non-production Supabase project.

create extension if not exists vector;
create extension if not exists pgcrypto;

create table if not exists rag_tenants (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  status text not null default 'active' check (status in ('active','suspended')),
  created_at timestamptz not null default now()
);

create table if not exists rag_users (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references rag_tenants(id) on delete cascade,
  external_user_id text not null,
  email text,
  display_name text,
  department text not null default 'support',
  role text not null default 'support_agent' check (role in ('viewer','support_agent','incident_manager','knowledge_admin')),
  clearance integer not null default 1 check (clearance between 0 and 5),
  status text not null default 'active' check (status in ('active','disabled')),
  created_at timestamptz not null default now(),
  unique (tenant_id, external_user_id)
);

create table if not exists rag_sources (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references rag_tenants(id) on delete cascade,
  source_key text not null,
  source_type text not null check (source_type in ('repository','drive','notion','upload','api')),
  display_name text not null,
  base_url text,
  trust_level integer not null default 3 check (trust_level between 1 and 5),
  allowed_departments text[] not null default array['support'],
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (tenant_id, source_key)
);

create table if not exists rag_documents (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references rag_tenants(id) on delete cascade,
  source_id uuid not null references rag_sources(id) on delete cascade,
  external_document_id text not null,
  title text not null,
  document_type text not null,
  version text not null,
  status text not null default 'active' check (status in ('draft','active','superseded','archived','quarantined')),
  effective_at timestamptz,
  expires_at timestamptz,
  sensitivity integer not null default 1 check (sensitivity between 0 and 5),
  allowed_roles text[] not null default array['support_agent','incident_manager','knowledge_admin'],
  source_url text,
  checksum text not null,
  prompt_injection_detected boolean not null default false,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, source_id, external_document_id, version)
);

create table if not exists rag_document_chunks (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references rag_tenants(id) on delete cascade,
  document_id uuid not null references rag_documents(id) on delete cascade,
  chunk_index integer not null,
  heading text,
  content text not null,
  token_count integer,
  embedding vector(1536),
  search_vector tsvector generated always as (
    to_tsvector('english', coalesce(heading,'') || ' ' || content)
  ) stored,
  citation_label text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (document_id, chunk_index)
);

-- n8n's native Supabase Vector Store node expects the conventional
-- content/metadata/embedding structure. Governance attributes are repeated in
-- metadata so retrieval can filter before generation.
create table if not exists rag_vector_documents (
  id bigserial primary key,
  content text not null,
  metadata jsonb not null default '{}'::jsonb,
  embedding vector(1536),
  search_vector tsvector generated always as (
    to_tsvector('english', content)
  ) stored,
  created_at timestamptz not null default now()
);

create table if not exists rag_customers (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references rag_tenants(id) on delete cascade,
  customer_key text not null,
  name text not null,
  plan text not null check (plan in ('Starter','Business','Enterprise')),
  support_tier text not null check (support_tier in ('standard','priority','premium')),
  status text not null default 'active',
  region text not null,
  account_owner text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (tenant_id, customer_key)
);

create table if not exists rag_tickets (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references rag_tenants(id) on delete cascade,
  customer_id uuid references rag_customers(id) on delete set null,
  ticket_key text not null,
  title text not null,
  description text not null,
  severity text not null check (severity in ('SEV-1','SEV-2','SEV-3','SEV-4')),
  status text not null check (status in ('draft','open','investigating','waiting_customer','resolved','closed')),
  owner_team text,
  response_due_at timestamptz,
  resolution_summary text,
  tags text[] not null default '{}',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, ticket_key)
);

create table if not exists rag_conversations (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references rag_tenants(id) on delete cascade,
  user_id uuid references rag_users(id) on delete set null,
  channel text not null check (channel in ('web','slack','api')),
  external_thread_id text,
  status text not null default 'open' check (status in ('open','escalated','closed')),
  summary text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists rag_messages (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references rag_tenants(id) on delete cascade,
  conversation_id uuid not null references rag_conversations(id) on delete cascade,
  role text not null check (role in ('user','assistant','tool','system')),
  content text not null,
  citations jsonb not null default '[]'::jsonb,
  confidence numeric(5,4),
  created_at timestamptz not null default now()
);

create table if not exists rag_retrieval_runs (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references rag_tenants(id) on delete cascade,
  conversation_id uuid references rag_conversations(id) on delete set null,
  query text not null,
  rewritten_query text,
  filters jsonb not null default '{}'::jsonb,
  retrieved_chunk_ids uuid[] not null default '{}',
  selected_chunk_ids uuid[] not null default '{}',
  top_score numeric(8,6),
  latency_ms integer,
  created_at timestamptz not null default now()
);

create table if not exists rag_tool_runs (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references rag_tenants(id) on delete cascade,
  conversation_id uuid references rag_conversations(id) on delete set null,
  tool_name text not null,
  risk_level text not null check (risk_level in ('read','write','external_write')),
  arguments jsonb not null,
  status text not null check (status in ('planned','approval_required','approved','rejected','executed','failed')),
  result jsonb,
  error_code text,
  created_at timestamptz not null default now(),
  completed_at timestamptz
);

create table if not exists rag_approvals (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references rag_tenants(id) on delete cascade,
  tool_run_id uuid not null references rag_tool_runs(id) on delete cascade,
  requested_by uuid references rag_users(id) on delete set null,
  approver_external_id text,
  decision text not null default 'pending' check (decision in ('pending','approved','rejected','expired')),
  reason text,
  expires_at timestamptz not null,
  decided_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists rag_feedback (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references rag_tenants(id) on delete cascade,
  conversation_id uuid references rag_conversations(id) on delete cascade,
  message_id uuid references rag_messages(id) on delete cascade,
  rating integer not null check (rating between 1 and 5),
  reason_code text,
  comment text,
  created_at timestamptz not null default now()
);

create table if not exists rag_evaluation_cases (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references rag_tenants(id) on delete cascade,
  case_key text not null,
  category text not null,
  question text not null,
  expected_behavior text not null,
  expected_citations text[] not null default '{}',
  minimum_score numeric(5,4) not null default 0.75,
  active boolean not null default true,
  unique (tenant_id, case_key)
);

create table if not exists rag_evaluation_results (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references rag_tenants(id) on delete cascade,
  evaluation_case_id uuid not null references rag_evaluation_cases(id) on delete cascade,
  answer text,
  retrieval_score numeric(5,4),
  groundedness_score numeric(5,4),
  citation_score numeric(5,4),
  permission_score numeric(5,4),
  tool_selection_score numeric(5,4),
  passed boolean not null,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists rag_audit_events (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references rag_tenants(id) on delete cascade,
  conversation_id uuid references rag_conversations(id) on delete set null,
  event_type text not null,
  actor text not null,
  correlation_id text not null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists rag_dlq (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid references rag_tenants(id) on delete cascade,
  workflow_module text not null,
  operation text not null,
  correlation_id text,
  sanitized_payload jsonb not null default '{}'::jsonb,
  error_code text not null,
  error_message text not null,
  attempts integer not null default 0,
  status text not null default 'open' check (status in ('open','ready_for_replay','resolved','discarded')),
  next_retry_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists rag_chunks_embedding_idx
  on rag_document_chunks using hnsw (embedding vector_cosine_ops);
create index if not exists rag_chunks_search_idx
  on rag_document_chunks using gin (search_vector);
create index if not exists rag_vector_embedding_idx
  on rag_vector_documents using hnsw (embedding vector_cosine_ops);
create index if not exists rag_vector_search_idx
  on rag_vector_documents using gin (search_vector);
create index if not exists rag_vector_metadata_idx
  on rag_vector_documents using gin (metadata);
create index if not exists rag_documents_scope_idx
  on rag_documents (tenant_id, status, sensitivity, effective_at);
create index if not exists rag_messages_conversation_idx
  on rag_messages (conversation_id, created_at);
create index if not exists rag_tickets_customer_idx
  on rag_tickets (tenant_id, customer_id, status);
create index if not exists rag_tool_runs_status_idx
  on rag_tool_runs (tenant_id, status, created_at);
create index if not exists rag_audit_correlation_idx
  on rag_audit_events (tenant_id, correlation_id, created_at);
create index if not exists rag_dlq_status_idx
  on rag_dlq (status, next_retry_at);

create or replace function rag_hybrid_search(
  p_tenant_id uuid,
  p_query_embedding vector(1536),
  p_query_text text,
  p_user_role text,
  p_user_clearance integer,
  p_department text,
  p_match_count integer default 12
)
returns table (
  chunk_id uuid,
  document_id uuid,
  title text,
  version text,
  heading text,
  content text,
  citation_label text,
  source_url text,
  semantic_score double precision,
  keyword_score real,
  combined_score double precision
)
language sql
stable
security invoker
as $$
  select
    c.id,
    d.id,
    d.title,
    d.version,
    c.heading,
    c.content,
    c.citation_label,
    d.source_url,
    1 - (c.embedding <=> p_query_embedding) as semantic_score,
    ts_rank_cd(c.search_vector, websearch_to_tsquery('english', p_query_text)) as keyword_score,
    (
      (1 - (c.embedding <=> p_query_embedding)) * 0.72 +
      ts_rank_cd(c.search_vector, websearch_to_tsquery('english', p_query_text)) * 0.28 +
      (s.trust_level::double precision / 100.0)
    ) as combined_score
  from rag_document_chunks c
  join rag_documents d on d.id = c.document_id
  join rag_sources s on s.id = d.source_id
  where c.tenant_id = p_tenant_id
    and d.status = 'active'
    and d.prompt_injection_detected = false
    and d.sensitivity <= p_user_clearance
    and p_user_role = any(d.allowed_roles)
    and p_department = any(s.allowed_departments)
    and (d.effective_at is null or d.effective_at <= now())
    and (d.expires_at is null or d.expires_at > now())
  order by combined_score desc
  limit greatest(1, least(p_match_count, 30));
$$;

create or replace function match_documents(
  query_embedding vector(1536),
  match_count int default 12,
  filter jsonb default '{}'::jsonb
)
returns table (
  id bigint,
  content text,
  metadata jsonb,
  embedding vector(1536),
  similarity double precision
)
language plpgsql
stable
security invoker
as $$
begin
  return query
  select
    v.id,
    v.content,
    v.metadata,
    v.embedding,
    1 - (v.embedding <=> query_embedding) as similarity
  from rag_vector_documents v
  where v.metadata @> filter
    and coalesce(v.metadata->>'status', 'active') = 'active'
    and coalesce((v.metadata->>'promptInjectionDetected')::boolean, false) = false
  order by v.embedding <=> query_embedding
  limit greatest(1, least(match_count, 30));
end;
$$;

alter table rag_tenants enable row level security;
alter table rag_users enable row level security;
alter table rag_sources enable row level security;
alter table rag_documents enable row level security;
alter table rag_document_chunks enable row level security;
alter table rag_vector_documents enable row level security;
alter table rag_customers enable row level security;
alter table rag_tickets enable row level security;
alter table rag_conversations enable row level security;
alter table rag_messages enable row level security;
alter table rag_retrieval_runs enable row level security;
alter table rag_tool_runs enable row level security;
alter table rag_approvals enable row level security;
alter table rag_feedback enable row level security;
alter table rag_evaluation_cases enable row level security;
alter table rag_evaluation_results enable row level security;
alter table rag_audit_events enable row level security;
alter table rag_dlq enable row level security;

comment on function rag_hybrid_search is
  'Tenant-, role-, clearance-, department-, version-, and injection-aware hybrid retrieval for the support agent.';
