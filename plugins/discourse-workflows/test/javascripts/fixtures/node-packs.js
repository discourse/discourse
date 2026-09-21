export const nodePackSummary = {
  id: 7,
  key: "example_pack",
  name: "Example pack",
  version: "1.2.0",
  description: "Generic declarative actions",
  icon: "cubes",
  color: "violet",
  enabled: true,
  palette_visible: true,
  node_count: 4,
  retired_count: 1,
  used_by_count: 1,
  destinations: ["https://api.example.com"],
  installed_by: { id: 1, username: "admin" },
  updated_at: "2026-09-21T00:00:00Z",
};

export const nodePackDetail = {
  ...nodePackSummary,
  homepage: "https://example.com/docs",
  credentials: [
    {
      key: "api",
      label: "Example API token",
      credential_types: ["bearer_token"],
      required: true,
    },
  ],
  nodes: [
    {
      identifier: "action:example_pack.choice",
      key: "choice",
      version: "1.0",
      label: "Choose an option",
      subtitle: "Choice · One label from a list",
      description: "Returns one choice",
      docs_url: "https://example.com/docs/choice",
      icon: "list-check",
      color: "violet",
      credential: "api",
      retired: false,
      introduced_in: "1.0.0",
      request: { method: "POST", url: "https://api.example.com/v1/choice" },
      used_by_count: 1,
    },
  ],
  used_by: [
    { id: 12, name: "Support routing", published: true, node_ids: ["choice"] },
  ],
  removal: { blocked: true, active_executions: 2 },
};

export const nodePackPreview = {
  manifest: {
    key: "example_pack",
    name: "Example pack",
    version: "1.2.0",
    description: "Generic declarative actions",
    homepage: "https://example.com/docs",
    icon: "cubes",
    color: "violet",
  },
  destinations: ["https://api.example.com", "https://audit.example.com"],
  credentials: nodePackDetail.credentials,
  nodes: [
    { ...nodePackDetail.nodes[0], change: "new" },
    {
      ...nodePackDetail.nodes[0],
      identifier: "action:example_pack.score",
      key: "score",
      label: "Score against a rubric",
      subtitle: "Score · A value across levels",
      change: "changed",
    },
  ],
  installed: null,
  change: "install",
  previously_approved_destinations: ["https://api.example.com"],
  warnings: [],
};
