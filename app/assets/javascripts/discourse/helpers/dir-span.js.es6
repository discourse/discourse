import { registerUnbound } from "discourse-common/lib/helpers";
import { isRTL } from "discourse/lib/text-direction";

function setDir(text) {
  let content = text ? text : "";
  if (content && Discourse.SiteSettings.support_mixed_text_direction) {
    let textDir = isRTL(content) ? "rtl" : "ltr";
    return `<span dir="${textDir}">${content}</span>`;
  }
  return content;
}

export default registerUnbound("dir-span", function(str) {
  return new Handlebars.SafeString(setDir(str));
});
