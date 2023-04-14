import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";
import { equal } from "@ember/object/computed";
import { isEmpty } from "@ember/utils";

export default Component.extend({
  tagName: "section",
  classNameBindings: [
    ":category-boxes-with-topics",
    "anyLogos:with-logos:no-logos",
  ],
  noCategoryStyle: equal("siteSettings.category_style", "none"),
  lockIcon: "lock",

  @discourseComputed("categories.[].uploaded_logo.url")
  anyLogos() {
    return this.categories.any((c) => {
      return !isEmpty(c.get("uploaded_logo.url"));
    });
  },
});
