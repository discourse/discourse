import Ember from "ember";
let initializedOnce = false;

export default {
  name: "ember-link-component-extensions",

  initialize() {
    if (initializedOnce) {
      return;
    }

    Ember.LinkComponent.reopen({
      attributeBindings: ["name"],
    });

    initializedOnce = true;
  },
};
