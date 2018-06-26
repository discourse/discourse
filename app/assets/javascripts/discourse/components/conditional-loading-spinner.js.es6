import computed from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  classNameBindings: [
    ":loading-container",
    "containerClass",
    "condition:visible"
  ],

  @computed("size")
  containerClass(size) {
    return size === "small" ? "inline-spinner" : undefined;
  }
});
