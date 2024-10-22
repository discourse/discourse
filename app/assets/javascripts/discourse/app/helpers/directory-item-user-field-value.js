import { htmlSafe } from "@ember/template";
import { generateUsersLink } from "discourse/helpers/generate-users-link";

export default function directoryItemUserFieldValue({ item, column }) {
  const userFields = item?.user?.user_fields;
  const fieldData = userFields ? userFields[column.user_field_id] : null;

  const value = fieldData?.searchable
    ? fieldData.value.map(generateUsersLink)
    : fieldData?.value;

  const content = value || "-";
  return htmlSafe(
    `<span class='directory-table__value--user-field'>${content}</span>`
  );
}
