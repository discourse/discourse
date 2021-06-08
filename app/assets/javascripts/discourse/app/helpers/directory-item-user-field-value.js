import { htmlSafe } from "@ember/template";
import { registerUnbound } from "discourse-common/lib/helpers";

export default registerUnbound(
  "directory-item-user-field-value",
  function (args) {
    // Args should include key/values { item, column }

    const value =
      args.item.user && args.item.user.user_fields
        ? args.item.user.user_fields[args.column.user_field_id]
        : null;
    const content = value || "-";
    return htmlSafe(`<span class='user-field-value'>${content}</span>`);
  }
);
