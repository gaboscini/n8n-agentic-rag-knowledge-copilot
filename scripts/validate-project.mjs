import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(fileURLToPath(new URL('..', import.meta.url)));
const workflowPath = join(root, 'workflows', 'enterprise-agentic-rag-support-control-plane.json');
const errors = [];
const warnings = [];

const read = (path) => readFileSync(join(root, path), 'utf8');
const workflow = JSON.parse(readFileSync(workflowPath, 'utf8'));
const functional = workflow.nodes.filter((node) => node.type !== 'n8n-nodes-base.stickyNote');
const notes = workflow.nodes.filter((node) => node.type === 'n8n-nodes-base.stickyNote');

if (workflow.active !== false) errors.push('Workflow export must remain inactive.');
if (workflow.name !== 'Enterprise Agentic RAG Support and Incident Control Plane') errors.push('Unexpected workflow name.');

const names = new Set();
const ids = new Set();
for (const node of workflow.nodes) {
  if (names.has(node.name)) errors.push('Duplicate node name: ' + node.name);
  if (ids.has(node.id)) errors.push('Duplicate node id: ' + node.id);
  names.add(node.name);
  ids.add(node.id);
  if (!Array.isArray(node.position) || node.position.length !== 2) errors.push('Invalid position: ' + node.name);
  if ('credentials' in node) errors.push('Embedded credentials object: ' + node.name);
  if (node.type === 'n8n-nodes-base.code') {
    try {
      new Function(node.parameters.jsCode);
    } catch (error) {
      errors.push('Code syntax error in ' + node.name + ': ' + error.message);
    }
  }
}

for (const [source, groups] of Object.entries(workflow.connections)) {
  if (!names.has(source)) errors.push('Connection source is missing: ' + source);
  for (const outputs of Object.values(groups)) {
    for (const output of outputs) {
      for (const target of output) {
        if (!names.has(target.node)) errors.push('Connection target is missing: ' + target.node);
      }
    }
  }
}

const connected = new Set(Object.keys(workflow.connections));
for (const groups of Object.values(workflow.connections)) {
  for (const outputs of Object.values(groups)) {
    for (const output of outputs) for (const target of output) connected.add(target.node);
  }
}
for (const node of functional) {
  if (!connected.has(node.name)) errors.push('Disconnected functional node: ' + node.name);
}

for (let i = 0; i < functional.length; i += 1) {
  for (let j = i + 1; j < functional.length; j += 1) {
    const a = functional[i];
    const b = functional[j];
    const dx = Math.abs(a.position[0] - b.position[0]);
    const dy = Math.abs(a.position[1] - b.position[1]);
    if (dx < 210 && dy < 90) errors.push('Possible node overlap: ' + a.name + ' / ' + b.name);
  }
}

for (const node of functional) {
  const covered = notes.filter((background) => {
    const [x, y] = background.position;
    const width = Number(background.parameters.width ?? 0);
    const height = Number(background.parameters.height ?? 0);
    return node.position[0] >= x && node.position[0] <= x + width && node.position[1] >= y && node.position[1] <= y + height;
  });
  if (covered.length !== 1) errors.push('Node must be covered by exactly one contextual note: ' + node.name + ' (' + covered.length + ')');
}

const nodeByName = new Map(workflow.nodes.map((node) => [node.name, node]));
const connectorSegments = [];
for (const [source, groups] of Object.entries(workflow.connections)) {
  for (const [connectionType, groupedOutputs] of Object.entries(groups)) {
    for (const outputs of groupedOutputs) {
      for (const target of outputs) {
        connectorSegments.push({
          source,
          target: target.node,
          connectionType,
          start: nodeByName.get(source).position,
          end: nodeByName.get(target.node).position,
        });
      }
    }
  }
}
const counterClockwise = (a, b, c) => (c[1] - a[1]) * (b[0] - a[0]) > (b[1] - a[1]) * (c[0] - a[0]);
const intersects = (a, b) => counterClockwise(a.start, b.start, b.end) !== counterClockwise(a.end, b.start, b.end)
  && counterClockwise(a.start, a.end, b.start) !== counterClockwise(a.start, a.end, b.end);
let crossingCount = 0;
for (let i = 0; i < connectorSegments.length; i += 1) {
  for (let j = i + 1; j < connectorSegments.length; j += 1) {
    const a = connectorSegments[i];
    const b = connectorSegments[j];
    if ([a.source, a.target].some((name) => name === b.source || name === b.target)) continue;
    if (intersects(a, b)) crossingCount += 1;
  }
}
if (crossingCount > 0) errors.push('Connectors cross on the generated canvas: ' + crossingCount);
const longestConnector = Math.max(...connectorSegments.map((segment) => Math.hypot(segment.end[0] - segment.start[0], segment.end[1] - segment.start[1])));
if (longestConnector > 650) errors.push('Connector exceeds the 650px layout budget: ' + Math.round(longestConnector) + 'px');

const expectedTypes = {
  '@n8n/n8n-nodes-langchain.openAi': 3,
  '@n8n/n8n-nodes-langchain.agent': 1,
  '@n8n/n8n-nodes-langchain.lmChatOpenAi': 1,
  '@n8n/n8n-nodes-langchain.outputParserStructured': 1,
  '@n8n/n8n-nodes-langchain.vectorStoreSupabase': 3,
  '@n8n/n8n-nodes-langchain.embeddingsOpenAi': 3,
  'n8n-nodes-base.supabase': 25,
  'n8n-nodes-base.slack': 6,
  'n8n-nodes-base.webhook': 4,
};
for (const [type, minimum] of Object.entries(expectedTypes)) {
  const count = workflow.nodes.filter((node) => node.type === type).length;
  if (count < minimum) errors.push('Expected at least ' + minimum + ' nodes of type ' + type + ', found ' + count);
}

const serializedWorkflow = JSON.stringify(workflow);
const legacyBrand = ['North', 'star'].join('');
if (new RegExp(legacyBrand, 'i').test(serializedWorkflow)) errors.push('Legacy fictional brand remains in workflow export.');
if (/"instanceId"\s*:/.test(serializedWorkflow)) errors.push('n8n instance identifier remains in workflow export.');
for (const unsafe of ['YOUR_OPENAI_API_KEY', 'service_role=', 'sk-proj-', 'ghp_']) {
  if (serializedWorkflow.includes(unsafe)) errors.push('Unsafe credential-like value in workflow: ' + unsafe);
}

const schema = read('supabase/schema.sql');
const tableMatches = [...schema.matchAll(/create table if not exists\s+([a-z0-9_]+)/gi)].map((match) => match[1]);
if (tableMatches.length < 18) errors.push('Expected at least 18 Supabase tables, found ' + tableMatches.length);
for (const table of tableMatches) {
  if (!schema.includes('alter table ' + table + ' enable row level security;')) errors.push('RLS not enabled for ' + table);
}
for (const requiredSql of ['create extension if not exists vector', 'create or replace function match_documents', 'create or replace function rag_hybrid_search', 'using hnsw', 'using gin']) {
  if (!schema.toLowerCase().includes(requiredSql.toLowerCase())) errors.push('Missing SQL control: ' + requiredSql);
}

const knowledgeFiles = readdirSync(join(root, 'knowledge')).filter((name) => name.endsWith('.md'));
if (knowledgeFiles.length !== 9) errors.push('Expected 9 synthetic knowledge documents, found ' + knowledgeFiles.length);
for (const file of knowledgeFiles) {
  const content = read(join('knowledge', file));
  for (const key of ['document_id:', 'title:', 'version:', 'department:', 'sensitivity:', 'authority:']) {
    if (!content.includes(key)) errors.push(file + ' is missing frontmatter field ' + key);
  }
}

const evalCases = JSON.parse(read('data/evaluation-cases.json'));
const customers = JSON.parse(read('data/synthetic-customers.json'));
const tickets = JSON.parse(read('data/synthetic-tickets.json'));
if (evalCases.length !== 10) errors.push('Expected 10 evaluation cases.');
if (customers.length !== 3) errors.push('Expected 3 synthetic customers.');
if (tickets.length !== 3) errors.push('Expected 3 synthetic tickets.');

const requiredFiles = [
  'README.md',
  'LICENSE',
  'SECURITY.md',
  'docs/ARCHITECTURE.md',
  'docs/SETUP.md',
  'docs/DEMO_GUIDE.md',
  'docs/TESTING.md',
  'docs/assets/architecture-overview.svg',
  'docs/assets/workflow-canvas.png',
  'supabase/schema.sql',
  'supabase/seed.sql',
  '.github/workflows/validate.yml',
];
for (const file of requiredFiles) {
  try {
    if (!statSync(join(root, file)).isFile()) errors.push('Missing required file: ' + file);
  } catch {
    errors.push('Missing required file: ' + file);
  }
}

function collectFiles(directory, output = []) {
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    if (entry.name === '.git' || entry.name === 'node_modules') continue;
    const path = join(directory, entry.name);
    if (entry.isDirectory()) collectFiles(path, output);
    else output.push(path);
  }
  return output;
}

const publicTextFiles = collectFiles(root).filter((path) => {
  const rel = relative(root, path).replaceAll('\\', '/');
  if (rel === 'scripts/validate-project.mjs') return false;
  return /\.(md|json|sql|yml|yaml|example|svg)$/i.test(path);
});
const personalName = ['Gabrielle', 'Faurillo'].join(' ');
const credentialPatterns = [
  /-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/,
  /AIza[0-9A-Za-z_-]{30,}/,
  /gh[pousr]_[0-9A-Za-z]{30,}/,
  /xox[baprs]-[0-9A-Za-z-]{20,}/,
];
for (const path of publicTextFiles) {
  const text = readFileSync(path, 'utf8');
  if (text.includes(personalName)) errors.push('Personal author name found in ' + relative(root, path));
  if (new RegExp(legacyBrand, 'i').test(text)) errors.push('Legacy fictional brand found in ' + relative(root, path));
  for (const pattern of credentialPatterns) if (pattern.test(text)) errors.push('Credential pattern found in ' + relative(root, path));
}

const screenshot = readFileSync(join(root, 'docs', 'assets', 'workflow-canvas.png'));
const pngSignature = '89504e470d0a1a0a';
if (screenshot.subarray(0, 8).toString('hex') !== pngSignature) errors.push('Workflow canvas asset is not a valid PNG.');
if (screenshot.length < 50_000) errors.push('Workflow canvas screenshot is unexpectedly small.');

if (functional.length < 110) warnings.push('Workflow has fewer than 110 functional nodes.');

const summary = {
  status: errors.length ? 'failed' : 'passed',
  workflow: workflow.name,
  totalNodes: workflow.nodes.length,
  functionalNodes: functional.length,
  backgroundNotes: notes.length,
  codeNodes: workflow.nodes.filter((node) => node.type === 'n8n-nodes-base.code').length,
  supabaseNodes: workflow.nodes.filter((node) => node.type === 'n8n-nodes-base.supabase').length,
  openAiNodes: workflow.nodes.filter((node) => node.type === '@n8n/n8n-nodes-langchain.openAi').length,
  vectorStoreNodes: workflow.nodes.filter((node) => node.type === '@n8n/n8n-nodes-langchain.vectorStoreSupabase').length,
  nativeAgentNodes: workflow.nodes.filter((node) => node.type === '@n8n/n8n-nodes-langchain.agent').length,
  connectorCrossings: crossingCount,
  longestConnectorPx: Math.round(longestConnector),
  knowledgeDocuments: knowledgeFiles.length,
  evaluationCases: evalCases.length,
  errors,
  warnings,
};

console.log(JSON.stringify(summary, null, 2));
if (errors.length) process.exit(1);
