import { htmlSafe } from "@ember/template";

export default function directoryItemUserFieldValue(args) {
  // Args should include key/values { item, column }
  const value =
    args.item.user && args.item.user.user_fields
      ? args.item.user.user_fields[args.column.user_field_id]
      : null;
  const content = value || "-";
  return htmlSafe(
    `<span class='directory-table__value--user-field'>${content}</span>`
  );
}
