import computed from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  tagName: "section",
  classNameBindings: [
    ":category-boxes-with-topics",
    "anyLogos:with-logos:no-logos"
  ],

  @computed("categories.[].uploaded_logo.url")
  anyLogos() {
    return this.get("categories").some(c => {
      return !Ember.isEmpty(c.get("uploaded_logo.url"));
    });
  }
});
