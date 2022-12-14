import Component from "@glimmer/component";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { equal, or } from "@ember/object/computed";
import { userPath } from "discourse/lib/url";
import { getOwner } from "discourse-common/lib/get-owner";

export default class StaticPage extends Component {
  @equal("model.path", "login") showLoginButton;
  @or("showLoginButton", "showSignupButton") anyButtons;

  get bodyClass() {
    return `static-${this.args.model.path}`;
  }

  get showSignupButton() {
    const application = getOwner(this).lookup("controller:application");
    return this.args.model.path === "login" && application.canSignUp;
  }

  @action
  async markFaqRead() {
    if (this.currentUser) {
      await ajax(userPath("read-faq"), { type: "POST" });
      this.currentUser.set("read_faq", true);
    }
  }
}
