export default {
  name: "ember-input-component-extensions",

  initialize() {
    Ember.TextSupport.reopen({
      attributeBindings: ["aria-describedby", "aria-invalid"],
    });
  },
};
