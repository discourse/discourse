import { ajax } from "discourse/lib/ajax";
import computed from "ember-addons/ember-computed-decorators";
import { userPath } from "discourse/lib/url";

export default Ember.Controller.extend({
  application: Ember.inject.controller(),

  showLoginButton: Ember.computed.equal("model.path", "login"),

  @computed("model.path")
  bodyClass: path => `static-${path}`,

  @computed("model.path")
  showSignupButton() {
    return (
      this.get("model.path") === "login" && this.get("application.canSignUp")
    );
  },

  actions: {
    markFaqRead() {
      const currentUser = this.currentUser;
      if (currentUser) {
        ajax(userPath("read-faq"), { method: "POST" }).then(() => {
          currentUser.set("read_faq", true);
        });
      }
    }
  }
});
