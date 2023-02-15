import { htmlSafe } from "@ember/template";
import { number } from "discourse/lib/formatter";
import { registerUnbound } from "discourse-common/lib/helpers";
import I18n from "I18n";

registerUnbound("mobile-directory-item-label", function (args) {
  // Args should include key/values { item, column }
  const count = args.item.get(args.column.name);
  const translationPrefix =
    args.column.type === "automatic" ? "directory." : "";
  return htmlSafe(I18n.t(`${translationPrefix}${args.column.name}`, { count }));
});

registerUnbound("directory-item-value", function (args) {
  // Args should include key/values { item, column }
  return htmlSafe(
    `<div class='number'>${number(args.item.get(args.column.name))}</div>`
  );
});

registerUnbound("directory-item-user-field-value", function (args) {
  // Args should include key/values { item, column }
  const value =
    args.item.user && args.item.user.user_fields
      ? args.item.user.user_fields[args.column.user_field_id]
      : null;
  const content = value || "-";
  return htmlSafe(`<div class='user-field-value'>${content}</div>`);
});

registerUnbound("directory-column-is-automatic", function (args) {
  // Args should include key/values { column }
  return args.column.type === "automatic";
});

registerUnbound("directory-column-is-user-field", function (args) {
  // Args should include key/values { column }
  return args.column.type === "user_field";
});
