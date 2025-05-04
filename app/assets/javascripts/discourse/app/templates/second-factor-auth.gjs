import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import RouteTemplate from "ember-route-template";
import { gt, not, or } from "truth-helpers";
import DButton from "discourse/components/d-button";
import SecondFactorInput from "discourse/components/second-factor-input";
import hideApplicationSidebar from "discourse/helpers/hide-application-sidebar";
import withEventValue from "discourse/helpers/with-event-value";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    {{hideApplicationSidebar}}

    {{#if @controller.message}}
      <div
        class="alert {{@controller.alertClass}}"
      >{{@controller.message}}</div>
    {{/if}}
    {{#unless @controller.loadError}}
      <h3>{{@controller.secondFactorTitle}}</h3>
      {{#if @controller.customDescription}}
        <p class="action-description">{{@controller.customDescription}}</p>
      {{/if}}
      <p>{{@controller.secondFactorDescription}}</p>
      {{#if @controller.showSecurityKeyForm}}
        <div id="security-key">
          <DButton
            @action={{@controller.authenticateSecurityKey}}
            @icon="key"
            @label="login.security_key_authenticate"
            id="security-key-authenticate-button"
            class="btn-large btn-primary"
          />
        </div>
      {{else if (or @controller.showTotpForm @controller.showBackupCodesForm)}}
        <form class={{@controller.inputFormClass}}>
          <SecondFactorInput
            {{on
              "input"
              (withEventValue (fn (mut @controller.secondFactorToken)))
            }}
            @secondFactorMethod={{@controller.shownSecondFactorMethod}}
            value={{@controller.secondFactorToken}}
          />

          <DButton
            @isLoading={{@controller.isLoading}}
            @disabled={{not @controller.isSecondFactorTokenValid}}
            @action={{@controller.authenticateToken}}
            @label="submit"
            type="submit"
            class="btn-primary"
          />
        </form>
      {{/if}}

      {{#if @controller.alternativeMethods.length}}
        <p>
          {{#each @controller.alternativeMethods as |method index|}}
            {{#if (gt index 0)}}
              <span>&middot;</span>
            {{/if}}
            <span>
              <a
                href
                class="toggle-second-factor-method {{method.class}}"
                {{on "click" (fn @controller.useAnotherMethod method.id)}}
              >
                {{i18n method.translationKey}}
              </a>
            </span>
          {{/each}}
        </p>
      {{/if}}
    {{/unless}}
  </template>
);
