import discourseComputed from "discourse-common/utils/decorators";
import Component from "@ember/component";
import { action } from "@ember/object";

export default Component.extend({
  @discourseComputed("value")
  selectedTags: {
    get(value) {
      return value.split("|").filter(Boolean);
    }
  },

  @action
  changeSelectedTags(tags) {
    this.set("value", tags.join("|"));
  }
});
