import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { htmlSafe } from "@ember/template";
import RouteTemplate from "ember-route-template";
import { and, not } from "truth-helpers";
import FlashMessage from "discourse/components/flash-message";
import FullnameInput from "discourse/components/fullname-input";
import HoneypotInput from "discourse/components/honeypot-input";
import InputTip from "discourse/components/input-tip";
import LoginButtons from "discourse/components/login-buttons";
import PasswordField from "discourse/components/password-field";
import PluginOutlet from "discourse/components/plugin-outlet";
import SignupPageCta from "discourse/components/signup-page-cta";
import SignupProgressBar from "discourse/components/signup-progress-bar";
import TogglePasswordMask from "discourse/components/toggle-password-mask";
import UserField from "discourse/components/user-field";
import WelcomeHeader from "discourse/components/welcome-header";
import bodyClass from "discourse/helpers/body-class";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import hideApplicationHeaderButtons from "discourse/helpers/hide-application-header-buttons";
import hideApplicationSidebar from "discourse/helpers/hide-application-sidebar";
import lazyHash from "discourse/helpers/lazy-hash";
import loadingSpinner from "discourse/helpers/loading-spinner";
import routeAction from "discourse/helpers/route-action";
import valueEntered from "discourse/helpers/value-entered";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    {{! template-lint-disable no-duplicate-id }}
    {{hideApplicationHeaderButtons "search" "login" "signup" "menu"}}
    {{hideApplicationSidebar}}
    {{bodyClass "signup-page"}}

    {{#if @controller.isRedirectingToExternalAuth}}
      {{! Hide the signup form if the site has only one external }}
      {{! authentication method and is being automatically redirected to it }}
      {{loadingSpinner}}
    {{else}}
      <div class="signup-fullpage">
        <FlashMessage
          @flash={{@controller.flash}}
          @type={{@controller.flashType}}
        />

        <div class={{concatClass "signup-body" @controller.bodyClasses}}>
          <PluginOutlet
            @name="create-account-before-modal-body"
            @connectorTagName="div"
          />

          <div
            class={{concatClass
              (if @controller.site.desktopView "login-left-side")
              @controller.authOptions.auth_provider
            }}
          >
            {{#unless @controller.skipConfirmation}}
              <SignupProgressBar @step={{@controller.progressBarStep}} />
              <WelcomeHeader
                id="create-account-title"
                @header={{i18n "create_account.header_title"}}
              >
                <PluginOutlet
                  @name="create-account-header-bottom"
                  @outletArgs={{lazyHash showLogin=(routeAction "showLogin")}}
                />
              </WelcomeHeader>
            {{/unless}}
            {{#if @controller.showCreateForm}}
              <form id="login-form">
                {{#if @controller.associateHtml}}
                  <div class="input-group create-account-associate-link">
                    <span>{{htmlSafe @controller.associateHtml}}</span>
                  </div>
                {{/if}}
                <div class="input-group create-account-email">
                  <Input
                    {{on "focusout" @controller.checkEmailAvailability}}
                    {{on "focusin" @controller.scrollInputIntoView}}
                    @type="email"
                    @value={{@controller.accountEmail}}
                    disabled={{@controller.emailDisabled}}
                    autofocus="autofocus"
                    aria-describedby="account-email-validation account-email-validation-more-info"
                    aria-invalid={{@controller.emailValidation.failed}}
                    name="email"
                    id="new-account-email"
                    class={{valueEntered @controller.accountEmail}}
                  />
                  <label class="alt-placeholder" for="new-account-email">
                    {{i18n "user.email.title"}}
                  </label>
                  {{#if @controller.showEmailValidation}}
                    <InputTip
                      @validation={{@controller.emailValidation}}
                      id="account-email-validation"
                    />
                  {{else}}
                    <span
                      class="more-info"
                      id="account-email-validation-more-info"
                    >
                      {{#if
                        @controller.siteSettings.show_signup_form_email_instructions
                      }}
                        {{i18n "user.email.instructions"}}
                      {{/if}}
                    </span>
                  {{/if}}
                </div>

                <div class="input-group create-account__username">
                  <input
                    {{on "focusin" @controller.scrollInputIntoView}}
                    {{on "input" @controller.setAccountUsername}}
                    type="text"
                    value={{@controller.accountUsername}}
                    disabled={{@controller.usernameDisabled}}
                    maxlength={{@controller.maxUsernameLength}}
                    aria-describedby="username-validation username-validation-more-info"
                    aria-invalid={{@controller.usernameValidation.failed}}
                    autocomplete="off"
                    name="username"
                    id="new-account-username"
                    class={{valueEntered @controller.accountUsername}}
                  />
                  <label class="alt-placeholder" for="new-account-username">
                    {{i18n "user.username.title"}}
                  </label>

                  {{#if @controller.showUsernameInstructions}}
                    <span class="more-info" id="username-validation-more-info">
                      {{i18n "user.username.instructions"}}
                    </span>

                  {{else}}
                    <InputTip
                      @validation={{@controller.usernameValidation}}
                      id="username-validation"
                    />
                  {{/if}}
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
                    class="input-group create-account__fullname required"
                  />
                {{/if}}

                <PluginOutlet
                  @name="create-account-before-password"
                  @outletArgs={{lazyHash
                    accountName=@controller.accountName
                    accountUsername=@controller.accountUsername
                    accountPassword=@controller.accountPassword
                    userFields=@controller.userFields
                    authOptions=@controller.authOptions
                  }}
                />

                <div class="input-group create-account__password">
                  {{#if @controller.passwordRequired}}
                    <PasswordField
                      {{on "focusin" @controller.scrollInputIntoView}}
                      @value={{@controller.accountPassword}}
                      @capsLockOn={{@controller.capsLockOn}}
                      type={{if @controller.maskPassword "password" "text"}}
                      autocomplete="current-password"
                      aria-describedby="password-validation password-validation-more-info"
                      aria-invalid={{@controller.passwordValidation.failed}}
                      id="new-account-password"
                      class={{valueEntered @controller.accountPassword}}
                    />
                    <label class="alt-placeholder" for="new-account-password">
                      {{i18n "user.password.title"}}
                    </label>
                    <TogglePasswordMask
                      @maskPassword={{@controller.maskPassword}}
                      @togglePasswordMask={{@controller.togglePasswordMask}}
                    />
                    <div class="create-account__password-info">
                      <div class="create-account__password-tip-validation">
                        {{#if @controller.showPasswordValidation}}
                          <InputTip
                            @validation={{@controller.passwordValidation}}
                            id="password-validation"
                          />
                        {{else if
                          @controller.siteSettings.show_signup_form_password_instructions
                        }}
                          <span
                            class="more-info"
                            id="password-validation-more-info"
                          >
                            {{@controller.passwordValidationHelper.passwordInstructions}}
                          </span>
                        {{/if}}
                        <div
                          class={{concatClass
                            "caps-lock-warning"
                            (unless @controller.capsLockOn "hidden")
                          }}
                        >
                          {{icon "triangle-exclamation"}}
                          {{i18n "login.caps_lock_warning"}}
                        </div>
                      </div>
                    </div>
                  {{/if}}

                  <div class="password-confirmation">
                    <label for="new-account-password-confirmation">
                      {{i18n "user.password_confirmation.title"}}
                    </label>
                    <HoneypotInput
                      @id="new-account-confirmation"
                      @autocomplete="new-password"
                      @value={{@controller.accountHoneypot}}
                    />
                    <Input
                      @value={{@controller.accountChallenge}}
                      id="new-account-challenge"
                    />
                  </div>
                </div>

                {{#if @controller.requireInviteCode}}
                  <div class="input-group create-account__invite-code">
                    <Input
                      {{on "focusin" @controller.scrollInputIntoView}}
                      @value={{@controller.inviteCode}}
                      id="inviteCode"
                      class={{valueEntered @controller.inviteCode}}
                    />
                    <label class="alt-placeholder" for="invite-code">
                      {{i18n "user.invite_code.title"}}
                    </label>
                    <span class="more-info">
                      {{i18n "user.invite_code.instructions"}}
                    </span>
                  </div>
                {{/if}}

                <PluginOutlet
                  @name="create-account-after-password"
                  @outletArgs={{lazyHash
                    accountName=@controller.accountName
                    accountUsername=@controller.accountUsername
                    accountPassword=@controller.accountPassword
                    userFields=@controller.userFields
                  }}
                />

                {{#if
                  (and
                    @controller.showFullname (not @controller.fullnameRequired)
                  )
                }}
                  <FullnameInput
                    @nameValidation={{@controller.nameValidation}}
                    @nameTitle={{@controller.nameTitle}}
                    @accountName={{@controller.accountName}}
                    @nameDisabled={{@controller.nameDisabled}}
                    @onFocusIn={{@controller.scrollInputIntoView}}
                    class="input-group create-account__fullname"
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
                          @validation={{f.validation}}
                          class={{valueEntered f.value}}
                        />
                      </div>
                    {{/each}}
                  </div>
                {{/if}}

                <PluginOutlet
                  @name="create-account-after-user-fields"
                  @outletArgs={{lazyHash
                    accountName=@controller.accountName
                    accountUsername=@controller.accountUsername
                    accountPassword=@controller.accountPassword
                    userFields=@controller.userFields
                  }}
                />
              </form>

              {{#if @controller.site.desktopView}}
                <SignupPageCta
                  @formSubmitted={{@controller.formSubmitted}}
                  @hasAuthOptions={{@controller.hasAuthOptions}}
                  @createAccount={{@controller.createAccount}}
                  @submitDisabled={{@controller.submitDisabled}}
                  @disclaimerHtml={{@controller.disclaimerHtml}}
                />
              {{/if}}
            {{/if}}

            {{#if @controller.skipConfirmation}}
              {{loadingSpinner size="large"}}
            {{/if}}
          </div>

          {{#if @controller.showRightSide}}
            {{#if @controller.site.mobileView}}
              <div class="login-or-separator">
                <span>{{i18n "login.or"}}</span>
              </div>
            {{/if}}
            <div class="login-right-side">
              <LoginButtons
                @externalLogin={{@controller.externalLogin}}
                @context="create-account"
              />
            </div>
          {{/if}}

          {{#if (and @controller.showCreateForm @controller.site.mobileView)}}
            <SignupPageCta
              @formSubmitted={{@controller.formSubmitted}}
              @hasAuthOptions={{@controller.hasAuthOptions}}
              @createAccount={{@controller.createAccount}}
              @submitDisabled={{@controller.submitDisabled}}
              @disclaimerHtml={{@controller.disclaimerHtml}}
            />
          {{/if}}
        </div>
      </div>
    {{/if}}
  </template>
);
