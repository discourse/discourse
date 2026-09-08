import { PostgreSQL, sql } from "@codemirror/lang-sql";

export default function sqlLanguage() {
  return sql({ dialect: PostgreSQL });
}
