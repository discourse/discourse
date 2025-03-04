import Component from "@ember/component";
import { on as on0 } from "@ember/modifier";
import { action } from "@ember/object";
import { on } from "@ember-decorators/object";
import DButton from "discourse/components/d-button";
import iN from "discourse/helpers/i18n";
import replaceEmoji from "discourse/helpers/replace-emoji";
import routeAction from "discourse/helpers/route-action";
import discourseLater from "discourse/lib/later";

export default class SignupCta extends Component {
  <template>
    <div class="signup-cta alert alert-info">
      {{#if this.session.hideSignupCta}}
        <h3>
          {{iN "signup_cta.hidden_for_session"}}
        </h3>
      {{else}}
        <h3>{{replaceEmoji (iN "signup_cta.intro")}}</h3>
        <p>{{replaceEmoji (iN "signup_cta.value_prop")}}</p>

        <div class="buttons">
          <DButton
            @action={{routeAction "showCreateAccount"}}
            @label="signup_cta.sign_up"
            @icon="user"
            class="btn-primary"
          />
          <DButton
            @action={{action "hideForSession"}}
            @label="signup_cta.hide_session"
            class="no-icon"
          />
          <a href {{on0 "click" this.neverShow}}>{{iN
              "signup_cta.hide_forever"
            }}</a>
        </div>
      {{/if}}
    </div>
  </template>
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
