import { findAll } from "discourse/models/login-method";
import computed from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  elementId: "login-buttons",
  classNameBindings: ["hidden"],

  @computed("buttons.length", "showLoginWithEmailLink")
  hidden(buttonsCount, showLoginWithEmailLink) {
    return buttonsCount === 0 && !showLoginWithEmailLink;
  },

  @computed
  buttons() {
    return findAll(
      this.siteSettings,
      this.capabilities,
      this.site.isMobileDevice
    );
  },

  actions: {
    emailLogin() {
      this.sendAction("emailLogin");
    },

    externalLogin(provider) {
      this.sendAction("externalLogin", provider);
    }
  }
});
