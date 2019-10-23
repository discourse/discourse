import Component from "@ember/component";
import { findAll } from "discourse/models/login-method";
import computed from "ember-addons/ember-computed-decorators";

export default Component.extend({
  elementId: "login-buttons",
  classNameBindings: ["hidden"],

  @computed("buttons.length", "showLoginWithEmailLink")
  hidden(buttonsCount, showLoginWithEmailLink) {
    return buttonsCount === 0 && !showLoginWithEmailLink;
  },

  @computed
  buttons() {
    return findAll();
  },

  actions: {
    externalLogin(provider) {
      this.externalLogin(provider);
    }
  }
});
