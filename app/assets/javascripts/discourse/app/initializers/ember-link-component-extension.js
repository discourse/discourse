export default {
  name: "ember-link-component-extensions",

  initialize() {
    Ember.LinkComponent.reopen({
      attributeBindings: ["name"],
    });
  },
};
