import { htmlSafe } from "@ember/template";
import I18n from "discourse-i18n";

export default function directoryItemLabel(args) {
  // Args should include key/values { item, column }
  const count = args.item.get(args.column.name);
  const translationPrefix =
    args.column.type === "automatic" ? "directory." : "";
  return htmlSafe(I18n.t(`${translationPrefix}${args.column.name}`, { count }));
}
