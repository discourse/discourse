import { htmlSafe } from "@ember/template";
import { registerUnbound } from "discourse-common/lib/helpers";

export default registerUnbound(
  "directory-item-user-field-value",
  function (item, column) {
    const value = item.user
      ? item.user.user_fields[column.user_field_id]
      : null;
    const content = value || "-";
    return htmlSafe(`<span class='user-field-value'>${content}</span>`);
  }
);
