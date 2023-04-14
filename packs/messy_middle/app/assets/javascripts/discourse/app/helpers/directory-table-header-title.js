import { registerUnbound } from "discourse-common/lib/helpers";
import I18n from "I18n";
import { iconHTML } from "discourse-common/lib/icon-library";
import { htmlSafe } from "@ember/template";

export default registerUnbound("directory-table-header-title", function (args) {
  // Args should include key/values { field, labelKey, icon, translated }

  let html = "";
  if (args.icon) {
    html += iconHTML(args.icon);
  }
  let labelKey = args.labelKey || `directory.${args.field}`;

  html += args.translated
    ? args.field
    : I18n.t(labelKey + "_long", { defaultValue: I18n.t(labelKey) });
  return htmlSafe(html);
});
