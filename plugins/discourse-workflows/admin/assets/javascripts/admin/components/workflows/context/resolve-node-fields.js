import { fieldVisible } from "../../../lib/workflows/property-engine";

function toFieldEntry(key, type) {
  return { key, type: type || "string", id: key };
}

function fieldsFromConfig(configArray) {
  if (!configArray?.length) {
    return null;
  }
  return configArray
    .filter((f) => f.key)
    .map((f) => toFieldEntry(f.key, f.type));
}

export function fieldsFromSchema(outputSchema) {
  if (!outputSchema || !Object.keys(outputSchema).length) {
    return null;
  }
  return Object.entries(outputSchema).map(([key, type]) =>
    toFieldEntry(key, type)
  );
}

export default function resolveNodeFields(node, nodeTypes) {
  const result =
    fieldsFromConfig(node.configuration?.output_fields) ||
    fieldsFromConfig(node.configuration?.fields);

  if (result) {
    return result;
  }

  const nodeType = nodeTypes.find((nt) => nt.identifier === node.type);
  const schema = nodeType?.output_schema;
  if (!schema || !Object.keys(schema).length) {
    return null;
  }

  const filtered = {};
  for (const [key, value] of Object.entries(schema)) {
    if (typeof value === "object" && value !== null) {
      if (fieldVisible(value, node.configuration || {})) {
        filtered[key] = value.type || "string";
      }
    } else {
      filtered[key] = value;
    }
  }

  return fieldsFromSchema(filtered);
}
