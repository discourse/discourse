import { htmlSafe } from "@ember/template";
import { iconHTML } from "discourse/lib/icon-library";
import { i18n } from "discourse-i18n";

export default function directoryTableHeaderTitle(args) {
  // Args should include key/values { field, icon, translated }

  let html = "";
  if (args.icon) {
    html += iconHTML(args.icon);
  }
  const labelKey = `directory.${args.field}`;

  html += args.translated
    ? args.field
    : i18n(`${labelKey}_long`, { defaultValue: i18n(labelKey) });
  return htmlSafe(html);
}
