import discourseComputed from "discourse-common/utils/decorators";
import { isEmpty } from "@ember/utils";
import Component from "@ember/component";

export default Component.extend({
  tagName: "section",
  classNameBindings: [
    ":category-boxes-with-topics",
    "anyLogos:with-logos:no-logos"
  ],

  @discourseComputed("categories.[].uploaded_logo.url")
  anyLogos() {
    return this.categories.any(c => {
      return !isEmpty(c.get("uploaded_logo.url"));
    });
  }
});
