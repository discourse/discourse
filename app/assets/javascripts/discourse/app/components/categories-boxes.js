import discourseComputed from "discourse-common/utils/decorators";
import { isEmpty } from "@ember/utils";
import Component from "@ember/component";
import { equal } from "@ember/object/computed";

export default Component.extend({
  tagName: "section",
  classNameBindings: [
    ":category-boxes",
    "anyLogos:with-logos:no-logos",
    "hasSubcategories:with-subcategories"
  ],
  noCategoryStyle: equal("siteSettings.category_style", "none"),

  @discourseComputed("categories.[].uploaded_logo.url")
  anyLogos() {
    return this.categories.any(c => !isEmpty(c.get("uploaded_logo.url")));
  },

  @discourseComputed("categories.[].subcategories")
  hasSubcategories() {
    return this.categories.any(c => !isEmpty(c.get("subcategories")));
  }
});
