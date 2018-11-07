import { htmlHelper } from "discourse-common/lib/helpers";
import { iconHTML, convertIconClass } from "discourse-common/lib/icon-library";

export default htmlHelper(function({ icon, image }) {
  if (!Ember.isEmpty(image)) {
    return `<img src='${image}'>`;
  }

  if (Ember.isEmpty(icon) || icon.indexOf("fa-") < 0) {
    return "";
  }

  icon = convertIconClass(icon);
  return iconHTML(icon);
});
