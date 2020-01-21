import discourseComputed from "discourse-common/utils/decorators";
import { isEmpty } from "@ember/utils";
import Component from "@ember/component";

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
  }
});
