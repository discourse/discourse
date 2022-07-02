import Component from "@ember/component";
import { action } from "@ember/object";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend({
  tagName: "",

  @discourseComputed("value")
  selectedTags: {
    get(value) {
      return value.split("|").filter(Boolean);
    },
  },

  @action
  changeSelectedTags(tags) {
    this.set("value", tags.join("|"));
  }
});
