import discourseComputed from "discourse-common/utils/decorators";
import { isEmpty } from "@ember/utils";
import Component from "@ember/component";
import DiscourseURL from "discourse/lib/url";

export default Component.extend({
  tagName: "section",
  classNameBindings: [
    ":category-boxes",
    "anyLogos:with-logos:no-logos",
    "hasSubcategories:with-subcategories"
  ],

  @discourseComputed("categories.[].uploaded_logo.url")
  anyLogos() {
    return this.categories.any(c => !isEmpty(c.get("uploaded_logo.url")));
  },

  @discourseComputed("categories.[].subcategories")
  hasSubcategories() {
    return this.categories.any(c => !isEmpty(c.get("subcategories")));
  },

  click(e) {
    if (!$(e.target).is("a")) {
      const url = $(e.target)
        .closest(".category-box")
        .data("url");
      if (url) {
        DiscourseURL.routeTo(url);
      }
    }
  }
});
