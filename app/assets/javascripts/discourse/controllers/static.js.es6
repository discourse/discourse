import discourseComputed from "discourse-common/utils/decorators";
import { equal } from "@ember/object/computed";
import { inject } from "@ember/controller";
import Controller from "@ember/controller";
import { ajax } from "discourse/lib/ajax";
import { userPath } from "discourse/lib/url";

export default Controller.extend({
  application: inject(),

  showLoginButton: equal("model.path", "login"),

  @discourseComputed("model.path")
  bodyClass: path => `static-${path}`,

  @discourseComputed("model.path")
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
