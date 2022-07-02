import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend({
  tagName: "",

  @discourseComputed("group.full_name")
  showFullName(fullName) {
    return fullName && fullName.length;
  }
});
