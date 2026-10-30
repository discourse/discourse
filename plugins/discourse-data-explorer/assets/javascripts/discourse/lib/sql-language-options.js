/** Language options completing the schema endpoint's tables and columns. */
export default function sqlLanguageOptions(schema) {
  if (!schema) {
    return undefined;
  }

  const tables = Object.fromEntries(
    Object.entries(schema).map(([table, columns]) => [
      table,
      columns.map((column) => ({
        label: column.column_name,
        type: "property",
        detail: column.data_type,
      })),
    ])
  );

  return { schema: tables };
}
