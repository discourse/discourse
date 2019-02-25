import computed from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  tagName: "",

  @computed("src")
  cdnSrc(src) {
    return Discourse.getURLWithCDN(src);
  },

  @computed("width", "height")
  style(width, height) {
    if (width && height) {
      return Ember.String.htmlSafe(`--aspect-ratio: ${width / height};`);
    }
  }
});
