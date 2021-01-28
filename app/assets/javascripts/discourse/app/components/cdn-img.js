import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";
import { getURLWithCDN } from "discourse-common/lib/get-url";
import { htmlSafe } from "@ember/template";

export default Component.extend({
  tagName: "",

  @discourseComputed("src")
  cdnSrc(src) {
    return getURLWithCDN(src);
  },

  @discourseComputed("width", "height")
  style(width, height) {
    if (width && height) {
      return htmlSafe(`--aspect-ratio: ${width / height};`);
    }
  },
});
