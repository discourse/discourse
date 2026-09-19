import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import hideApplicationSidebar from "discourse/helpers/hide-application-sidebar";
import { gt, not, or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DSecondFactorInput from "discourse/ui-kit/d-second-factor-input";
import { i18n } from "discourse-i18n";

export default <template>
  {{hideApplicationSidebar}}

  {{#if @controller.message}}
    <div class="alert {{@controller.alertClass}}">{{@controller.message}}</div>
  {{/if}}
  {{#unless @controller.loadError}}
    <h3>{{@controller.secondFactorTitle}}</h3>
    {{#if @controller.customDescription}}
      <p class="action-description">{{@controller.customDescription}}</p>
    {{/if}}
    <p>{{@controller.secondFactorDescription}}</p>
    {{#if @controller.showPasskeyForm}}
      <div id="security-key">
        <DButton
          class="btn-large btn-primary"
          id="passkey-authenticate-button"
          @action={{@controller.authenticatePasskey}}
          @icon="user"
          @label="login.use_passkey"
        />
      </div>
    {{else if @controller.showSecurityKeyForm}}
      <div id="security-key">
        <DButton
          class="btn-large btn-primary"
          id="security-key-authenticate-button"
          @action={{@controller.authenticateSecurityKey}}
          @icon="key"
          @label="login.security_key_authenticate"
        />
      </div>
    {{else if (or @controller.showTotpForm @controller.showBackupCodesForm)}}
      <form class={{@controller.inputFormClass}}>
        <DSecondFactorInput
          value={{@controller.secondFactorToken}}
          @onChange={{fn (mut @controller.secondFactorToken)}}
          @secondFactorMethod={{@controller.shownSecondFactorMethod}}
        />

        <DButton
          class="btn-primary"
          type="submit"
          @action={{@controller.authenticateToken}}
          @disabled={{not @controller.isSecondFactorTokenValid}}
          @isLoading={{@controller.isLoading}}
          @label="submit"
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
              class="toggle-second-factor-method {{method.class}}"
              href
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
