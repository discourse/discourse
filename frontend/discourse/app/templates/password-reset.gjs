import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import SecondFactorForm from "discourse/components/second-factor-form";
import SecurityKeyForm from "discourse/components/security-key-form";
import bodyClass from "discourse/helpers/body-class";
import hideApplicationHeaderButtons from "discourse/helpers/hide-application-header-buttons";
import hideApplicationSidebar from "discourse/helpers/hide-application-sidebar";
import DButton from "discourse/ui-kit/d-button";
import DInputTip from "discourse/ui-kit/d-input-tip";
import DPasswordField from "discourse/ui-kit/d-password-field";
import DSecondFactorInput from "discourse/ui-kit/d-second-factor-input";
import DTogglePasswordMask from "discourse/ui-kit/d-toggle-password-mask";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default <template>
  {{bodyClass "password-reset-page"}}
  {{hideApplicationSidebar}}
  {{hideApplicationHeaderButtons "search" "login" "signup" "menu"}}
  <div class="container password-reset clearfix">
    <form class="change-password-form login-left-side">
      {{#if @controller.successMessage}}
        <p>{{@controller.successMessage}}</p>

        {{#if @controller.requiresApproval}}
          <p>{{i18n "login.not_approved"}}</p>
        {{else}}
          {{#unless @controller.redirected}}
            <a
              class="btn"
              href={{@controller.redirectHref}}
              {{on "click" @controller.done}}
            >{{@controller.continueButtonText}}</a>
          {{/unless}}
        {{/if}}
      {{else}}
        {{#if @controller.securityKeyOrSecondFactorRequired}}
          <h2>{{i18n "user.change_password.title"}}</h2>
          <p>
            {{i18n "user.change_password.verify_identity"}}
          </p>
          {{#if @controller.errorMessage}}
            <div class="alert alert-error">{{@controller.errorMessage}}</div>
            <br />
          {{/if}}

          {{#if @controller.displaySecurityKeyForm}}
            <SecurityKeyForm
              @action={{@controller.authenticateSecurityKey}}
              @backupEnabled={{@controller.backupEnabled}}
              @otherMethodAllowed={{@controller.otherMethodAllowed}}
              @setSecondFactorMethod={{fn
                (mut @controller.selectedSecondFactorMethod)
              }}
              @totpEnabled={{@controller.secondFactorRequired}}
            />
          {{else}}
            <SecondFactorForm
              @backupEnabled={{@controller.backupEnabled}}
              @isLogin={{false}}
              @secondFactorMethod={{@controller.selectedSecondFactorMethod}}
              @secondFactorToken={{@controller.secondFactorToken}}
              @totpEnabled={{@controller.secondFactorRequired}}
            >
              <DSecondFactorInput
                id="second-factor"
                value={{@controller.secondFactorToken}}
                @onChange={{fn (mut @controller.secondFactorToken)}}
                @secondFactorMethod={{@controller.selectedSecondFactorMethod}}
              />
            </SecondFactorForm>
          {{/if}}

          {{#unless @controller.displaySecurityKeyForm}}
            <DButton
              class="btn-primary"
              type="submit"
              @action={{@controller.submit}}
              @isLoading={{@controller.isLoading}}
              @label="submit"
            />
          {{/unless}}
        {{else}}
          <h2>{{i18n "user.change_password.choose_new"}}</h2>
          {{#if @controller.errorMessage}}
            <div class="alert alert-error">{{@controller.errorMessage}}</div>
            <br />
          {{/if}}

          <div class="input">
            <DPasswordField
              autocomplete="new-password"
              autofocus="autofocus"
              id="new-account-password"
              type={{if @controller.maskPassword "password" "text"}}
              @capsLockOn={{@controller.capsLockOn}}
              @value={{@controller.accountPassword}}
            />
            <div class="change-password__password-info">
              <div class="change-password_tip-validation">
                {{#if @controller.showPasswordValidation}}
                  <DInputTip @validation={{@controller.passwordValidation}} />
                {{/if}}
                <div
                  class="caps-lock-warning
                    {{unless @controller.capsLockOn 'hidden'}}"
                >
                  {{dIcon "triangle-exclamation"}}
                  {{i18n "login.caps_lock_warning"}}
                </div>
              </div>
              <DTogglePasswordMask
                @maskPassword={{@controller.maskPassword}}
                @togglePasswordMask={{@controller.togglePasswordMask}}
              />
            </div>
          </div>

          <DButton
            class="btn-primary"
            type="submit"
            @action={{@controller.submit}}
            @isLoading={{@controller.isLoading}}
            @label="user.change_password.set_password"
          />
        {{/if}}
      {{/if}}
    </form>
  </div>
</template>
