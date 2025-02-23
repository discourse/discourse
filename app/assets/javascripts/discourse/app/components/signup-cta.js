import Component from "@ember/component";
import { action } from "@ember/object";
import { on } from "@ember-decorators/object";
import discourseLater from "discourse/lib/later";

export default class SignupCta extends Component {
  action = "showCreateAccount";

  @action
  neverShow(event) {
    event?.preventDefault();
    this.keyValueStore.setItem("anon-cta-never", "t");
    this.session.set("showSignupCta", false);
  }

  @action
  hideForSession() {
    this.session.set("hideSignupCta", true);
    this.keyValueStore.setItem("anon-cta-hidden", Date.now());
    discourseLater(() => this.session.set("showSignupCta", false), 20 * 1000);
  }

  @on("willDestroyElement")
  _turnOffIfHidden() {
    if (this.session.get("hideSignupCta")) {
      this.session.set("showSignupCta", false);
    }
  }
}
