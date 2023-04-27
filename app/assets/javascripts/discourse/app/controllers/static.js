import Controller, { inject as controller } from "@ember/controller";
import discourseComputed from "discourse-common/utils/decorators";
import { equal, or } from "@ember/object/computed";

export default Controller.extend({
  application: controller(),

  showLoginButton: equal("model.path", "login"),
  anyButtons: or("showLoginButton", "showSignupButton"),

  @discourseComputed("model.path")
  bodyClass: (path) => `static-${path}`,

  @discourseComputed("model.path")
  showSignupButton() {
    return (
      this.get("model.path") === "login" && this.get("application.canSignUp")
    );
  },
});
