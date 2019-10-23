import Component from "@ember/component";
import computed from "ember-addons/ember-computed-decorators";

export default Component.extend({
  tagName: "section",
  classNameBindings: [
    ":category-boxes-with-topics",
    "anyLogos:with-logos:no-logos"
  ],

  @computed("categories.[].uploaded_logo.url")
  anyLogos() {
    return this.categories.any(c => {
      return !Ember.isEmpty(c.get("uploaded_logo.url"));
    });
  }
});
