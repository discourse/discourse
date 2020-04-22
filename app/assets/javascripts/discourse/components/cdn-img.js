import discourseComputed from "discourse-common/utils/decorators";
import Component from "@ember/component";
import { htmlSafe } from "@ember/template";

export default Component.extend({
  tagName: "",

  @discourseComputed("src")
  cdnSrc(src) {
    return Discourse.getURLWithCDN(src);
  },

  @discourseComputed("width", "height")
  style(width, height) {
    if (width && height) {
      return htmlSafe(`--aspect-ratio: ${width / height};`);
    }
  }
});
