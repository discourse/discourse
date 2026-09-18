import { PostgreSQL, sql } from "@codemirror/lang-sql";

export default function sqlLanguage(cmParams, options = {}) {
  return sql({ dialect: PostgreSQL, ...options });
}
