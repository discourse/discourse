import discourseComputed from "discourse-common/utils/decorators";
import Component from "@ember/component";

export default Component.extend({
  tagName: "span",
  classNames: ["group-info-details"],

  @discourseComputed("group.full_name", "group.title")
  showFullName(fullName, title) {
    return fullName && fullName.length && fullName !== title;
  }
});
