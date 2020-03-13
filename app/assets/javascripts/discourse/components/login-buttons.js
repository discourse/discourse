import discourseComputed from "discourse-common/utils/decorators";
import Component from "@ember/component";
import { findAll } from "discourse/models/login-method";

export default Component.extend({
  elementId: "login-buttons",
  classNameBindings: ["hidden"],

  @discourseComputed("buttons.length", "showLoginWithEmailLink")
  hidden(buttonsCount, showLoginWithEmailLink) {
    return buttonsCount === 0 && !showLoginWithEmailLink;
  },

  @discourseComputed
  buttons() {
    return findAll();
  },

  actions: {
    externalLogin(provider) {
      this.externalLogin(provider);
    }
  }
});
