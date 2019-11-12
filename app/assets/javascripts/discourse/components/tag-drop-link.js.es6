import discourseComputed from "discourse-common/utils/decorators";
import Component from "@ember/component";
import DiscourseURL from "discourse/lib/url";

export default Component.extend({
  tagName: "a",
  classNameBindings: [
    ":tag-badge-wrapper",
    ":badge-wrapper",
    ":bullet",
    "tagClass"
  ],
  attributeBindings: ["href"],

  @discourseComputed("tagId", "category")
  href(tagId, category) {
    var url = "/tags";
    if (category) {
      url += category.url;
    }
    return url + "/" + tagId;
  },

  @discourseComputed("tagId")
  tagClass(tagId) {
    return "tag-" + tagId;
  },

  click(e) {
    e.preventDefault();
    DiscourseURL.routeTo(this.href);
    return true;
  }
});
