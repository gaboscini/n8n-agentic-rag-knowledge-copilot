import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const workflowPath = fileURLToPath(new URL('../workflows/enterprise-agentic-rag-support-control-plane.json', import.meta.url));
const workflow = JSON.parse(readFileSync(workflowPath, 'utf8'));

const normalized = structuredClone(workflow);
normalized.name = 'Enterprise Agentic RAG Support and Incident Control Plane';
normalized.active = false;
normalized.meta = {
  templateCredsSetupCompleted: false,
  portfolioProject: true,
  domain: 'B2B SaaS support and incident resolution',
};

const webhookPaths = {
  '01 - Knowledge Ingestion Webhook': 'agentic-rag-knowledge-ingest',
  '02 - Support Agent Gateway': 'agentic-rag-support-agent',
  '03 - Human Approval Webhook': 'agentic-rag-action-approval',
  '04 - Answer Feedback Webhook': 'agentic-rag-answer-feedback',
  '99 - Failure Intake Webhook': 'agentic-rag-failure-intake',
};
for (const node of normalized.nodes) {
  delete node.credentials;
  if (webhookPaths[node.name]) node.parameters.path = webhookPaths[node.name];
}

normalized.connections['01.15c - Semantic Text Splitter'] = {
  ai_textSplitter: [[{
    node: '01.15b - Default Document Loader',
    type: 'ai_textSplitter',
    index: 0,
  }]],
};

const serialized = JSON.stringify(normalized, null, 2) + '\n';
if (/"instanceId"\s*:/.test(serialized)) throw new Error('n8n instance identifier remains in workflow export.');

writeFileSync(workflowPath, serialized, 'utf8');
console.log(JSON.stringify({
  workflowPath,
  name: normalized.name,
  nodes: normalized.nodes.length,
  connectionSources: Object.keys(normalized.connections).length,
}, null, 2));
