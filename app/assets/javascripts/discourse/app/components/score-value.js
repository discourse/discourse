import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend({
  tagName: "",

  @discourseComputed("value")
  isNegative: function () {
    return this.value < 0;
  },
});
