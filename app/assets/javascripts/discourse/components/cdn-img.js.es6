import computed from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  tagName: "",

  @computed("src")
  cdnSrc(src) {
    return Discourse.getURLWithCDN(src);
  }
});
