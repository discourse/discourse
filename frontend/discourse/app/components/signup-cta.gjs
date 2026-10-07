/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import { tagName } from "@ember-decorators/component";
import { on } from "@ember-decorators/object";
import routeAction from "discourse/helpers/route-action";
import discourseLater from "discourse/lib/later";
import DButton from "discourse/ui-kit/d-button";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";
import { i18n } from "discourse-i18n";

@tagName("")
export default class SignupCta extends Component {
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

  @on("willDestroyElement")
  _turnOffIfHidden() {
    if (this.session.get("hideSignupCta")) {
      this.session.set("showSignupCta", false);
    }
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
