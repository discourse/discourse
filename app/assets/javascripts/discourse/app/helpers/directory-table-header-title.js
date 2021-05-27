import { registerUnbound } from "discourse-common/lib/helpers";
import I18n from "I18n";
import { iconHTML } from "discourse-common/lib/icon-library";
import { htmlSafe } from "@ember/template";

export default registerUnbound(
  "directory-table-header-title",
  function (field, labelKey, icon, translated) {
    let html = "";
    if (icon) {
      html += iconHTML(icon);
    }

    if (!labelKey) {
      labelKey = `directory.${field}`;
    }

    html += translated
      ? field
      : I18n.t(labelKey + "_long", { defaultValue: I18n.t(labelKey) });
    return htmlSafe(html);
  }
);
