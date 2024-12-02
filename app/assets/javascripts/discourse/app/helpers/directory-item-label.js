import { htmlSafe } from "@ember/template";
import { i18n } from "discourse-i18n";

export default function directoryItemLabel(args) {
  // Args should include key/values { item, column }
  const count = args.item.get(args.column.name);
  const translationPrefix =
    args.column.type === "automatic" ? "directory." : "";
  return htmlSafe(i18n(`${translationPrefix}${args.column.name}`, { count }));
}
