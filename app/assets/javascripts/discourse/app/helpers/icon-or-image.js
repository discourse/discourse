import { isEmpty } from "@ember/utils";
import { htmlHelper } from "discourse-common/lib/helpers";
import { iconHTML, convertIconClass } from "discourse-common/lib/icon-library";

export default htmlHelper(function({ icon, image }) {
  if (!isEmpty(image)) {
    return `<img src='${image}'>`;
  }

  if (isEmpty(icon)) {
    return "";
  }

  icon = convertIconClass(icon);
  return iconHTML(icon);
});
