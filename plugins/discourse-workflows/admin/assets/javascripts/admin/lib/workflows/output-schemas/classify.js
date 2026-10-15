import { fixedCollectionRows } from "../property-engine.js";

function answerSchema(type) {
  const properties = {
    type: { type: "string" },
    reason: { type: ["string", "null"] },
  };

  if (type === "yes_no") {
    properties.probability = { type: "number" };
  } else if (type === "choice" || type === "score") {
    properties.probabilities = { type: "object" };
    properties.confidence = { type: ["number", "null"] };
    if (type === "choice") {
      properties.choice = { type: "string" };
    } else {
      properties.score = { type: "number" };
      properties.level = { type: "string" };
    }
  }

  return { type: "object", properties };
}

export default function classifyOutputSchemas(configuration = {}) {
  const answers = new Map();
  for (const row of fixedCollectionRows(configuration.questions)) {
    if (!row || typeof row !== "object" || Array.isArray(row)) {
      continue;
    }

    const name = String(row.name ?? "").trim();
    if (name) {
      answers.set(name, answerSchema(row.type));
    }
  }

  return [
    {
      $schema: "https://json-schema.org/draft/2020-12/schema",
      type: "object",
      properties: {
        classification: {
          type: "object",
          properties: Object.fromEntries(answers),
        },
      },
    },
  ];
}
