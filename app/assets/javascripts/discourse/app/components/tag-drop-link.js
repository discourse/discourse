import Component from "@ember/component";
import DiscourseURL from "discourse/lib/url";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend({
  tagName: "a",
  classNameBindings: [
    ":tag-badge-wrapper",
    ":badge-wrapper",
    ":bullet",
    "tagClass",
  ],
  attributeBindings: ["href"],

  @discourseComputed("tagId", "category")
  href(tagId, category) {
    if (category) {
      return "/tags" + category.url + "/" + tagId;
    } else {
      return "/tag/" + tagId;
    }
  },

  @discourseComputed("tagId")
  tagClass(tagId) {
    return "tag-" + tagId;
  },

  click(e) {
    e.preventDefault();
    DiscourseURL.routeTo(this.href);
    return true;
  },
});
