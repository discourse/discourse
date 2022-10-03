import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";
import { htmlSafe } from "@ember/template";

export default Component.extend({
  tagName: "",

  @discourseComputed("width", "height")
  style(width, height) {
    if (width && height) {
      return htmlSafe(`--aspect-ratio: ${width / height};`);
    }
  },
});
