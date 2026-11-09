import { PostgreSQL, sql } from "@codemirror/lang-sql";

/** `schema` maps table names to their columns, each a name or completion. */
export default function sqlLanguage(cmParams, { schema } = {}) {
  return sql({ dialect: PostgreSQL, schema });
}
