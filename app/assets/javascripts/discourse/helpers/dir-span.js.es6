import { registerUnbound } from "discourse-common/lib/helpers";
import { isRTL } from 'discourse/lib/text-direction';

function setDir(text) {
  if (Discourse.SiteSettings.support_mixed_text_direction) {
    let textDir = isRTL(text) ? 'rtl' : 'ltr';
    return `<span dir="${textDir}">${text}</span>`;
  }
  return text;
}

export default registerUnbound('dir-span', function(str) {
  return new Handlebars.SafeString(setDir(str));
});
