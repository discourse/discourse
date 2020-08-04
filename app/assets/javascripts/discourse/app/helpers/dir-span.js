import { registerUnbound, helperContext } from "discourse-common/lib/helpers";
import { isRTL } from "discourse/lib/text-direction";
import { htmlSafe } from "@ember/template";

function setDir(text) {
  let content = text ? text : "";
  let siteSettings = helperContext().siteSettings;
  if (content && siteSettings.support_mixed_text_direction) {
    let textDir = isRTL(content) ? "rtl" : "ltr";
    return `<span dir="${textDir}">${content}</span>`;
  }
  return content;
}

export default registerUnbound("dir-span", function(str) {
  return htmlSafe(setDir(str));
});
