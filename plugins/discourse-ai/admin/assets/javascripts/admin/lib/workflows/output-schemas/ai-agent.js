const DRAFT_URI = "https://json-schema.org/draft/2020-12/schema";

function schemaTypeFor(field) {
  if (field.type !== "array") {
    return { type: field.type };
  }

  const schema = {
    type: "array",
    items: { type: field.array_type || "string" },
  };
  if (Number.isInteger(field.max_items) && field.max_items >= 0) {
    schema.maxItems = field.max_items;
  }

  return schema;
}

export default function aiAgentOutputSchemas(configuration = {}) {
  const properties = { result: { type: "string" } };
  const fields = Array.isArray(configuration.agent_response_format)
    ? configuration.agent_response_format
    : [];

  for (const field of fields) {
    if (field?.key) {
      properties[field.key] = schemaTypeFor(field);
    }
  }

  return [{ $schema: DRAFT_URI, type: "object", properties }];
}
