import { fixedCollectionRows } from "../property-engine";
import { summarizeOutputKey } from "../summarize-output-key";

const DRAFT_URI = "https://json-schema.org/draft/2020-12/schema";
const NUMBER_TYPE = { type: ["number", "null"] };
const INTEGER_TYPE = { type: "integer" };
const STRING_TYPE = { type: "string" };
const ARRAY_TYPE = { type: "array" };
const ANY_TYPE = {};

function schemaTypeFor(row = {}) {
  switch (String(row.aggregation ?? "")) {
    case "count":
    case "count_unique":
      return INTEGER_TYPE;
    case "sum":
    case "average":
      return NUMBER_TYPE;
    case "concatenate":
      return STRING_TYPE;
    case "append":
    case "collect":
    case "unique":
      return ARRAY_TYPE;
    default:
      return ANY_TYPE;
  }
}

function splitFieldList(value) {
  return String(value ?? "")
    .split(",")
    .map((field) => field.trim())
    .filter(Boolean);
}

function leafName(field) {
  return field.includes(".") ? field.split(".").pop() : field;
}

export default function summarizeOutputSchemas(configuration = {}) {
  const properties = {};

  for (const field of splitFieldList(configuration.fields_to_split_by)) {
    properties[leafName(field)] = ANY_TYPE;
  }
  for (const row of fixedCollectionRows(configuration.fields_to_summarize)) {
    properties[summarizeOutputKey(row)] = schemaTypeFor(row);
  }

  return [{ $schema: DRAFT_URI, type: "object", properties }];
}
