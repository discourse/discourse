import Component from "@ember/component";
import DiscourseURL from "discourse/lib/url";
import computed from "ember-addons/ember-computed-decorators";

export default Component.extend({
  tagName: "a",
  classNameBindings: [
    ":tag-badge-wrapper",
    ":badge-wrapper",
    ":bullet",
    "tagClass"
  ],
  attributeBindings: ["href"],

  @computed("tagId", "category")
  href(tagId, category) {
    var url = "/tags";
    if (category) {
      url += category.url;
    }
    return url + "/" + tagId;
  },

  @computed("tagId")
  tagClass(tagId) {
    return "tag-" + tagId;
  },

  click(e) {
    e.preventDefault();
    DiscourseURL.routeTo(this.href);
    return true;
  }
});
