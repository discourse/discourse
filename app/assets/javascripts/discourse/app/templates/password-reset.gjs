import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import RouteTemplate from "ember-route-template";
import DButton from "discourse/components/d-button";
import InputTip from "discourse/components/input-tip";
import PasswordField from "discourse/components/password-field";
import SecondFactorForm from "discourse/components/second-factor-form";
import SecondFactorInput from "discourse/components/second-factor-input";
import SecurityKeyForm from "discourse/components/security-key-form";
import TogglePasswordMask from "discourse/components/toggle-password-mask";
import bodyClass from "discourse/helpers/body-class";
import icon from "discourse/helpers/d-icon";
import hideApplicationHeaderButtons from "discourse/helpers/hide-application-header-buttons";
import hideApplicationSidebar from "discourse/helpers/hide-application-sidebar";
import withEventValue from "discourse/helpers/with-event-value";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
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
                @setSecondFactorMethod={{fn
                  (mut @controller.selectedSecondFactorMethod)
                }}
                @backupEnabled={{@controller.backupEnabled}}
                @totpEnabled={{@controller.secondFactorRequired}}
                @otherMethodAllowed={{@controller.otherMethodAllowed}}
                @action={{@controller.authenticateSecurityKey}}
              />
            {{else}}
              <SecondFactorForm
                @secondFactorMethod={{@controller.selectedSecondFactorMethod}}
                @secondFactorToken={{@controller.secondFactorToken}}
                @backupEnabled={{@controller.backupEnabled}}
                @totpEnabled={{@controller.secondFactorRequired}}
                @isLogin={{false}}
              >
                <SecondFactorInput
                  {{on
                    "input"
                    (withEventValue (fn (mut @controller.secondFactorToken)))
                  }}
                  @secondFactorMethod={{@controller.selectedSecondFactorMethod}}
                  value={{@controller.secondFactorToken}}
                  id="second-factor"
                />
              </SecondFactorForm>
            {{/if}}

            {{#unless @controller.displaySecurityKeyForm}}
              <DButton
                @isLoading={{@controller.isLoading}}
                @action={{@controller.submit}}
                @label="submit"
                type="submit"
                class="btn-primary"
              />
            {{/unless}}
          {{else}}
            <h2>{{i18n "user.change_password.choose_new"}}</h2>
            {{#if @controller.errorMessage}}
              <div class="alert alert-error">{{@controller.errorMessage}}</div>
              <br />
            {{/if}}

            <div class="input">
              <PasswordField
                @value={{@controller.accountPassword}}
                @capsLockOn={{@controller.capsLockOn}}
                type={{if @controller.maskPassword "password" "text"}}
                autofocus="autofocus"
                autocomplete="new-password"
                id="new-account-password"
              />
              <div class="change-password__password-info">
                <div class="change-password_tip-validation">
                  {{#if @controller.showPasswordValidation}}
                    <InputTip @validation={{@controller.passwordValidation}} />
                  {{/if}}
                  <div
                    class="caps-lock-warning
                      {{unless @controller.capsLockOn 'hidden'}}"
                  >
                    {{icon "triangle-exclamation"}}
                    {{i18n "login.caps_lock_warning"}}
                  </div>
                </div>
                <TogglePasswordMask
                  @maskPassword={{@controller.maskPassword}}
                  @togglePasswordMask={{@controller.togglePasswordMask}}
                />
              </div>
            </div>

            <DButton
              @isLoading={{@controller.isLoading}}
              @action={{@controller.submit}}
              @label="user.change_password.set_password"
              type="submit"
              class="btn-primary"
            />
          {{/if}}
        {{/if}}
      </form>
    </div>
  </template>
);
