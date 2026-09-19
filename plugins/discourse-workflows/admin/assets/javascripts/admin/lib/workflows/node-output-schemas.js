import summarize from "./output-schemas/summarize";

// Nodes whose output keys come from what the author typed cannot declare them as a contract, so
// they compute them in Ruby and name an editor-side counterpart through `output_schema_resolver`.
const RESOLVERS = { summarize };

export function outputSchemasFromResolver(resolver, configuration = {}) {
  if (!resolver) {
    return null;
  }

  return RESOLVERS[resolver]?.(configuration || {}) || null;
}
