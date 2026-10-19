// Mirrors DiscourseWorkflows::Nodes::Summarize::V1.output_key so the editor can show
// which field an aggregation will write to before the workflow runs.
const OUTPUT_PREFIXES = {
  append: "appended_",
  average: "average_",
  collect: "collected_",
  concatenate: "concatenated_",
  count: "count_",
  count_unique: "unique_count_",
  first: "first_",
  last: "last_",
  max: "max_",
  min: "min_",
  sum: "sum_",
  unique: "unique_",
};

function leafName(field) {
  return field.includes(".") ? field.split(".").pop() : field;
}

function sanitizeKey(name) {
  return String(name)
    .replace(/["[\]]/g, "")
    .replace(/[ .]/g, "_");
}

export function fieldKey(field, fields) {
  const leaf = leafName(field);
  if (fields.filter((other) => leafName(other) === leaf).length < 2) {
    return leaf;
  }

  return sanitizeKey(field);
}

function derivedFields(rows, aggregation) {
  return rows
    .filter(
      (row) =>
        String(row.aggregation ?? "") === aggregation &&
        summarizeOutputKeyIsDerived(row)
    )
    .map((row) => String(row.field ?? "").trim())
    .filter(Boolean);
}

export function summarizeOutputKey(row = {}, rows = [row]) {
  const explicit = String(row.output_field_name ?? "").trim();
  if (explicit) {
    return explicit;
  }

  const aggregation = String(row.aggregation ?? "");
  const prefix = OUTPUT_PREFIXES[aggregation] ?? "";
  const field = String(row.field ?? "").trim();

  if (!field) {
    return prefix.replace(/_$/, "");
  }

  return `${prefix}${sanitizeKey(
    fieldKey(field, derivedFields(rows, aggregation))
  )}`;
}

export function summarizeOutputKeyIsDerived(row = {}) {
  return !String(row.output_field_name ?? "").trim();
}
