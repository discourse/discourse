import { htmlHelper } from "discourse-common/lib/helpers";
import { iconHTML } from "discourse-common/lib/icon-library";

export default htmlHelper(function({ icon, image }) {
  if (!Ember.isEmpty(image)) {
    return `<img src='${image}'>`;
  }

  if (Ember.isEmpty(icon) || icon.indexOf("fa-") < 0) {
    return "";
  }

  icon = icon.replace("far fa-", "far-");
  icon = icon.replace("fab fa-", "fab-");
  icon = icon.replace("fa-", "");

  return iconHTML(icon);
});
