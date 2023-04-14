import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend({
  tagName: "span",
  classNames: ["group-info-details"],

  @discourseComputed("group.full_name")
  showFullName(fullName) {
    return fullName && fullName.length;
  },
});
