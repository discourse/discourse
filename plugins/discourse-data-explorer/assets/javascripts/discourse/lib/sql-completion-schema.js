/**
 * Reshapes the schema endpoint's payload into the table/column namespace the
 * editor completes against, carrying each column's type through as the detail
 * shown beside it.
 *
 * @param {object} schema tables keyed by name, each a list of column records
 */
export default function sqlCompletionSchema(schema) {
  if (!schema) {
    return null;
  }

  return Object.fromEntries(
    Object.entries(schema).map(([table, columns]) => [
      table,
      columns.map((column) => ({
        label: column.column_name,
        type: "property",
        detail: column.data_type,
      })),
    ])
  );
}
