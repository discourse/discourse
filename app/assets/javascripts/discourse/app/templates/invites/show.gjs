import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { htmlSafe } from "@ember/template";
import RouteTemplate from "ember-route-template";
import { and, not, or } from "truth-helpers";
import DButton from "discourse/components/d-button";
import FullnameInput from "discourse/components/fullname-input";
import InputTip from "discourse/components/input-tip";
import LoginButtons from "discourse/components/login-buttons";
import PasswordField from "discourse/components/password-field";
import SignupProgressBar from "discourse/components/signup-progress-bar";
import TogglePasswordMask from "discourse/components/toggle-password-mask";
import UserField from "discourse/components/user-field";
import UserInfo from "discourse/components/user-info";
import WelcomeHeader from "discourse/components/welcome-header";
import bodyClass from "discourse/helpers/body-class";
import icon from "discourse/helpers/d-icon";
import hideApplicationHeaderButtons from "discourse/helpers/hide-application-header-buttons";
import hideApplicationSidebar from "discourse/helpers/hide-application-sidebar";
import routeAction from "discourse/helpers/route-action";
import valueEntered from "discourse/helpers/value-entered";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    {{bodyClass "invite-page"}}
    {{hideApplicationHeaderButtons "search" "login" "signup" "menu"}}
    {{hideApplicationSidebar}}
    <section>
      <div class="container invites-show clearfix">
        {{#unless
          (or @controller.externalAuthsOnly @controller.existingUserId)
        }}
          <SignupProgressBar
            @step={{if @controller.successMessage "activate" "signup"}}
          />
        {{/unless}}
        <WelcomeHeader @header={{@controller.welcomeTitle}} />

        <div
          class={{if @controller.successMessage "invite-success" "invite-form"}}
        >
          <div class="col-form">
            {{#if @controller.successMessage}}
              <div class="success-info">
                <p>{{htmlSafe @controller.successMessage}}</p>
              </div>
            {{else}}
              <div class="invited-by">
                <p>{{i18n "invites.invited_by"}}</p>
                <p>
                  <UserInfo @user={{@controller.invitedBy}} />
                </p>
              </div>

              {{#if @controller.associateHtml}}
                <p class="create-account-associate-link">
                  {{htmlSafe @controller.associateHtml}}
                </p>
              {{/if}}

              {{#unless @controller.isInviteLink}}
                <p class="email-message">
                  {{htmlSafe @controller.yourEmailMessage}}
                  {{#if @controller.showSocialLoginAvailable}}
                    {{i18n "invites.social_login_available"}}
                  {{/if}}
                </p>
              {{/unless}}

              {{#if @controller.externalAuthsOnly}}
                {{! authOptions are present once the user has followed the OmniAuth flow (e.g. twitter/google/etc) }}
                {{#if @controller.authOptions}}
                  {{#unless @controller.isInviteLink}}
                    <InputTip
                      @validation={{@controller.emailValidation}}
                      id="account-email-validation"
                    />
                  {{/unless}}
                {{else}}
                  <LoginButtons
                    @externalLogin={{@controller.externalLogin}}
                    @context="invite"
                  />
                {{/if}}
              {{/if}}

              {{#if @controller.discourseConnectEnabled}}
                <a
                  class="btn btn-primary discourse-connect raw-link"
                  href={{@controller.ssoPath}}
                >
                  {{i18n "continue"}}
                </a>
              {{/if}}

              {{#if @controller.shouldDisplayForm}}
                <form>
                  {{#if @controller.isInviteLink}}
                    <div class="input email-input input-group">
                      <Input
                        {{on "focusin" @controller.scrollInputIntoView}}
                        @type="email"
                        @value={{@controller.email}}
                        id="new-account-email"
                        name="email"
                        class={{valueEntered @controller.email}}
                        autofocus="autofocus"
                        disabled={{@controller.externalAuthsOnly}}
                      />
                      <label class="alt-placeholder" for="new-account-email">
                        {{i18n "user.email.title"}}
                      </label>
                      <InputTip
                        @validation={{@controller.emailValidation}}
                        id="account-email-validation"
                      />
                      {{#unless @controller.emailValidation.reason}}
                        <div class="instructions">
                          {{i18n "user.email.instructions"}}
                        </div>
                      {{/unless}}
                    </div>
                  {{/if}}

                  <div class="input username-input input-group">
                    <input
                      {{on "focusin" @controller.scrollInputIntoView}}
                      {{on "input" @controller.setAccountUsername}}
                      type="text"
                      value={{@controller.accountUsername}}
                      class={{valueEntered @controller.accountUsername}}
                      id="new-account-username"
                      name="username"
                      maxlength={{@controller.maxUsernameLength}}
                      autocomplete="off"
                    />
                    <label class="alt-placeholder" for="new-account-username">
                      {{i18n "user.username.title"}}
                    </label>
                    <InputTip
                      @validation={{@controller.usernameValidation}}
                      id="username-validation"
                    />
                  </div>

                  {{#if
                    (and @controller.showFullname @controller.fullnameRequired)
                  }}
                    <FullnameInput
                      @nameValidation={{@controller.nameValidation}}
                      @nameTitle={{@controller.nameTitle}}
                      @accountName={{@controller.accountName}}
                      @nameDisabled={{@controller.nameDisabled}}
                      @onFocusIn={{@controller.scrollInputIntoView}}
                      class="input name-input input-group name-required"
                    />
                  {{/if}}

                  {{#unless @controller.externalAuthsOnly}}
                    <div class="input password-input input-group">
                      <PasswordField
                        {{on "focusin" @controller.scrollInputIntoView}}
                        @value={{@controller.accountPassword}}
                        @capsLockOn={{@controller.capsLockOn}}
                        type={{if @controller.maskPassword "password" "text"}}
                        autocomplete="new-password"
                        id="new-account-password"
                        class={{valueEntered @controller.accountPassword}}
                      />
                      <label class="alt-placeholder" for="new-account-password">
                        {{i18n "invites.password_label"}}
                      </label>
                      <TogglePasswordMask
                        @maskPassword={{@controller.maskPassword}}
                        @togglePasswordMask={{@controller.togglePasswordMask}}
                        @parentController="invites-show"
                      />
                      <div class="create-account__password-info">
                        <div class="create-account__password-tip-validation">
                          <InputTip
                            @validation={{@controller.passwordValidation}}
                            id="password-validation"
                          />
                          <div
                            class="caps-lock-warning
                              {{unless @controller.capsLockOn 'hidden'}}"
                          >
                            {{icon "triangle-exclamation"}}
                            {{i18n "login.caps_lock_warning"}}
                          </div>
                        </div>
                      </div>
                    </div>
                  {{/unless}}

                  {{#if
                    (and
                      @controller.showFullname
                      (not @controller.fullnameRequired)
                    )
                  }}
                    <FullnameInput
                      @nameValidation={{@controller.nameValidation}}
                      @nameTitle={{@controller.nameTitle}}
                      @accountName={{@controller.accountName}}
                      @nameDisabled={{@controller.nameDisabled}}
                      @onFocusIn={{@controller.scrollInputIntoView}}
                      class="input name-input input-group"
                    />
                  {{/if}}

                  {{#if @controller.userFields}}
                    <div class="user-fields">
                      {{#each @controller.userFields as |f|}}
                        <div class="input-group">
                          <UserField
                            {{on "focusin" @controller.scrollInputIntoView}}
                            @field={{f.field}}
                            @value={{f.value}}
                            class={{valueEntered f.value}}
                          />
                        </div>
                      {{/each}}
                    </div>
                  {{/if}}

                  <div class="invitation-cta">
                    <DButton
                      @action={{@controller.submit}}
                      @disabled={{@controller.submitDisabled}}
                      @label="invites.accept_invite"
                      type="submit"
                      class="btn-primary invitation-cta__accept"
                    />
                    <div class="invitation-cta__info">
                      <span class="invitation-cta__signed-up">{{i18n
                          "login.previous_sign_up"
                        }}</span>
                      <DButton
                        @action={{routeAction "showLogin"}}
                        @label="log_in"
                        class="btn-flat invitation-cta__sign-in"
                      />
                    </div>
                  </div>

                  <div class="disclaimer">
                    {{htmlSafe @controller.disclaimerHtml}}
                  </div>

                  {{#if @controller.errorMessage}}
                    <br /><br />
                    <div
                      class="alert alert-error"
                    >{{@controller.errorMessage}}</div>
                  {{/if}}
                </form>
              {{/if}}
              {{#if @controller.existingUserRedeeming}}
                {{#if @controller.existingUserCanRedeem}}
                  <DButton
                    @action={{@controller.submit}}
                    @disabled={{@controller.submitDisabled}}
                    @label="invites.accept_invite"
                    type="submit"
                    class="btn-primary"
                  />
                {{else}}
                  <div
                    class="alert alert-error"
                  >{{@controller.existingUserCanRedeemError}}</div>
                {{/if}}
              {{/if}}
            {{/if}}
          </div>
        </div>
      </div>
    </section>
  </template>
);
