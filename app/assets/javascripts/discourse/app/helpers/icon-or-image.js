import { convertIconClass, iconHTML } from "discourse-common/lib/icon-library";
import { htmlHelper } from "discourse-common/lib/helpers";
import { isEmpty } from "@ember/utils";

export default htmlHelper(function ({ icon, image }) {
  if (!isEmpty(image)) {
    return `<img src='${image}'>`;
  }

  if (isEmpty(icon)) {
    return "";
  }

  icon = convertIconClass(icon);
  return iconHTML(icon);
});
