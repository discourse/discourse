import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import routeAction from "discourse/helpers/route-action";
import discourseLater from "discourse/lib/later";
import DButton from "discourse/ui-kit/d-button";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";
import { i18n } from "discourse-i18n";

export default class SignupCta extends Component {
  @service keyValueStore;
  @service session;

  willDestroy() {
    super.willDestroy(...arguments);

    if (this.session.get("hideSignupCta")) {
      this.session.set("showSignupCta", false);
    }
  }

  @action
  hideForSession() {
    this.session.set("hideSignupCta", true);
    this.keyValueStore.setItem("anon-cta-hidden", Date.now());
    discourseLater(() => this.session.set("showSignupCta", false), 20 * 1000);
  }

  @action
  hideForever() {
    this.session.set("showSignupCta", false);
    this.keyValueStore.setItem("anon-cta-never", "t");
  }

  <template>
    <div class="signup-cta alert alert-info" ...attributes>
      {{#if this.session.hideSignupCta}}
        <h3>{{i18n "signup_cta.hidden_for_session"}}</h3>
      {{else}}
        <h3>{{dReplaceEmoji (trustHTML (i18n "signup_cta.intro"))}}</h3>
        <p>{{dReplaceEmoji (trustHTML (i18n "signup_cta.value_prop"))}}</p>

        <div class="buttons">
          <DButton
            class="btn-primary"
            @action={{routeAction "showCreateAccount"}}
            @icon="user"
            @label="signup_cta.sign_up"
          />
          <DButton
            class="btn-default no-icon"
            @action={{this.hideForSession}}
            @label="signup_cta.hide_session"
          />
          <DButton
            class="no-icon btn-flat"
            @action={{this.hideForever}}
            @label="signup_cta.hide_forever"
          />
        </div>
      {{/if}}
    </div>
  </template>
}
