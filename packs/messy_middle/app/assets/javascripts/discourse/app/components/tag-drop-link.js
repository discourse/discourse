import Component from "@ember/component";
import DiscourseURL from "discourse/lib/url";
import discourseComputed from "discourse-common/utils/decorators";
import getURL from "discourse-common/lib/get-url";

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
    let path;

    if (category) {
      path = "/tags" + category.path + "/" + tagId;
    } else {
      path = "/tag/" + tagId;
    }

    return getURL(path);
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
