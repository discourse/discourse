const pack = {
  id: 7,
  key: "example_pack",
  name: "Example pack",
  version: "1.2.0",
  definition_version: "1.0",
  retired: false,
};

function nodeType({ key, label, subtitle, properties, outputProperties }) {
  const definition = {
    name: `action:example_pack.${key}`,
    identifier: `action:example_pack.${key}`,
    version: "1.0",
    displayName: `discourse_workflows.nodes.action:example_pack.${key}`,
    ui: {
      icon: "wand-magic-sparkles",
      color: "violet",
      label,
      description: `<img src=x onerror=alert(1)> ${label} description`,
      subtitle,
      docs_url: `https://example.com/docs/${key}`,
      palette_group: {
        id: "pack:example_pack",
        label: "Example pack",
        icon: "cubes",
        order: 207,
      },
      pack,
    },
    credentials: [
      {
        name: "auth",
        credential_types: ["bearer_token"],
        required: true,
        label: "Example API token",
      },
    ],
    properties,
    output_contracts: [
      {
        schema: {
          $schema: "https://json-schema.org/draft/2020-12/schema",
          type: "object",
          properties: outputProperties,
        },
        mode: "replace",
        display_options: {},
        variants: [],
        extensions: [],
      },
    ],
    palette_visible: true,
    available: true,
    examples: [],
  };

  return {
    ...definition,
    latest: definition,
    versions: { "1.0": definition },
  };
}

export const packNodeTypes = [
  nodeType({
    key: "choice",
    label: "Choose an option",
    subtitle: "Choice · One label from a list",
    properties: {
      model: {
        type: "options",
        required: true,
        default: "latest",
        options: ["latest", { value: "stable", label: "Stable model" }],
        label: "Model",
      },
      state: {
        type: "string",
        required: true,
        ui: { control: "textarea" },
        label: "State",
        description: "<img src=x onerror=alert(1)>",
        placeholder: "{{ $json.post.raw }}",
      },
      options: {
        type: "fixed_collection",
        required: true,
        label: "Options",
        type_options: { multiple_values: true, min_required_fields: 2 },
        options: [
          {
            name: "values",
            values: {
              key: { type: "string", required: true, label: "Key" },
              description: { type: "string", label: "Description" },
            },
          },
        ],
      },
    },
    outputProperties: {
      choice: { type: "string" },
      confidence: { type: "number" },
    },
  }),
  nodeType({
    key: "score",
    label: "Score against a rubric",
    subtitle: "Score · A value across defined levels",
    properties: {
      state: { type: "string", required: true, label: "State" },
      levels: {
        type: "fixed_collection",
        required: true,
        label: "Levels",
        options: [
          {
            name: "values",
            values: {
              description: { type: "string", required: true, label: "Level" },
            },
          },
        ],
      },
    },
    outputProperties: { score: { type: "number" } },
  }),
  nodeType({
    key: "check",
    label: "Check a statement",
    subtitle: "Check · Probability a statement is true",
    properties: {
      state: { type: "string", required: true, label: "State" },
      statement: { type: "string", required: true, label: "Statement" },
    },
    outputProperties: { probability: { type: "number" } },
  }),
  nodeType({
    key: "batch",
    label: "Evaluate questions",
    subtitle: "Batch · Several judgments, one request",
    properties: {
      state: { type: "string", required: true, label: "State" },
      questions: {
        type: "fixed_collection",
        required: true,
        label: "Questions",
        options: [
          {
            name: "values",
            values: {
              id: { type: "string", required: true, label: "Answer id" },
              criteria: {
                type: "string",
                label: "Criteria (JSON)",
                ui: { control: "textarea", format: "json" },
              },
            },
          },
        ],
      },
    },
    outputProperties: { answers: { type: "object" } },
  }),
];

export default packNodeTypes;
