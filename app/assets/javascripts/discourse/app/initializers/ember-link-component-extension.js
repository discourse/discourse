let initializedOnce = false;

export default {
  name: "ember-link-component-extensions",

  initialize() {
    if (initializedOnce) {
      return;
    }

    // eslint-disable-next-line no-undef
    Ember.LinkComponent.reopen({
      attributeBindings: ["name"],
    });

    initializedOnce = true;
  },
};
