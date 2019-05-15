import computed from "ember-addons/ember-computed-decorators";
import DiscourseURL from "discourse/lib/url";

export default Ember.Component.extend({
  tagName: "section",
  classNameBindings: [
    ":category-boxes",
    "anyLogos:with-logos:no-logos",
    "hasSubcategories:with-subcategories"
  ],

  @computed("categories.[].uploaded_logo.url")
  anyLogos() {
    return this.get("categories").any(
      c => !Ember.isEmpty(c.get("uploaded_logo.url"))
    );
  },

  @computed("categories.[].subcategories")
  hasSubcategories() {
    return this.get("categories").any(
      c => !Ember.isEmpty(c.get("subcategories"))
    );
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
