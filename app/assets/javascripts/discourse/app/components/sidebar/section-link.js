import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";
import { htmlSafe } from "@ember/template";

export default Component.extend({
  @discourseComputed("prefixIconColor")
  prefixCSS(color) {
    if (!color || !color.match(/^\w{6}$/)) {
      return htmlSafe("");
    }
    return htmlSafe("color: #" + color);
  },
});
