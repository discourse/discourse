import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { trustHTML } from "@ember/template";
import CodeLoginForm from "discourse/components/code-login-form";
import FullnameInput from "discourse/components/fullname-input";
import HoneypotInput from "discourse/components/honeypot-input";
import LoginButtons from "discourse/components/login-buttons";
import NoLoginMethods from "discourse/components/no-login-methods";
import PluginOutlet from "discourse/components/plugin-outlet";
import SignupPageCta from "discourse/components/signup-page-cta";
import SignupProgressBar from "discourse/components/signup-progress-bar";
import UserField from "discourse/components/user-field";
import WelcomeHeader from "discourse/components/welcome-header";
import bodyClass from "discourse/helpers/body-class";
import hideApplicationHeaderButtons from "discourse/helpers/hide-application-header-buttons";
import hideApplicationSidebar from "discourse/helpers/hide-application-sidebar";
import lazyHash from "discourse/helpers/lazy-hash";
import routeAction from "discourse/helpers/route-action";
import valueEntered from "discourse/helpers/value-entered";
import { and, not } from "discourse/truth-helpers";
import DFlashMessage from "discourse/ui-kit/d-flash-message";
import DInputTip from "discourse/ui-kit/d-input-tip";
import DPasswordField from "discourse/ui-kit/d-password-field";
import DTogglePasswordMask from "discourse/ui-kit/d-toggle-password-mask";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dLoadingSpinner from "discourse/ui-kit/helpers/d-loading-spinner";
import { i18n } from "discourse-i18n";

export default <template>
  {{hideApplicationHeaderButtons "search" "login" "signup" "menu"}}
  {{hideApplicationSidebar}}
  {{bodyClass "signup-page"}}

  <div class="signup-fullpage">
    <DFlashMessage
      @flash={{@controller.flash}}
      @type={{@controller.flashType}}
    />

    <div class={{dConcatClass "signup-body" @controller.bodyClasses}}>
      <PluginOutlet
        @connectorTagName="div"
        @name="create-account-before-modal-body"
      />

      <div
        class={{dConcatClass
          (if @controller.site.desktopView "login-left-side")
          @controller.authOptions.auth_provider
        }}
      >
        {{#if @controller.hasNoLoginOptions}}
          <NoLoginMethods />
        {{else if (not @controller.skipConfirmation)}}
          {{! Code signup renders its own heading inside CodeLoginForm. }}
          {{#unless @controller.showCodeSignupForm}}
            <SignupProgressBar @step={{@controller.progressBarStep}} />
            <PluginOutlet
              @name="signup-heading"
              @outletArgs={{lazyHash
                step="form"
                context="signup"
                title=(i18n "create_account.header_title")
              }}
            >
              <WelcomeHeader
                id="create-account-title"
                @header={{i18n "create_account.header_title"}}
              >
                <PluginOutlet
                  @name="create-account-header-bottom"
                  @outletArgs={{lazyHash showLogin=(routeAction "showLogin")}}
                />
              </WelcomeHeader>
            </PluginOutlet>
          {{/unless}}
        {{/if}}
        {{#if @controller.showCodeSignupForm}}
          <CodeLoginForm
            @context="signup"
            @initialEmail={{@controller.accountEmail}}
            @onStepChange={{@controller.updateCodeSignupStep}}
          />
          {{#if
            (and @controller.codeSignupOnEmailStep @controller.disclaimerHtml)
          }}
            <div class="signup-page-cta__disclaimer">
              {{trustHTML @controller.disclaimerHtml}}
            </div>
          {{/if}}
        {{/if}}
        {{#if @controller.showCreateForm}}
          <form id="login-form">
            {{#if @controller.associateHtml}}
              <div class="input-group create-account-associate-link">
                <span>{{trustHTML @controller.associateHtml}}</span>
              </div>
            {{/if}}
            <div class="input-group create-account-email">
              <Input
                aria-describedby="account-email-validation account-email-validation-more-info"
                aria-invalid={{@controller.emailValidation.failed}}
                autofocus="autofocus"
                class={{valueEntered @controller.accountEmail}}
                disabled={{@controller.emailDisabled}}
                id="new-account-email"
                name="email"
                @type="email"
                @value={{@controller.accountEmail}}
                {{on "focusout" @controller.checkEmailAvailability}}
                {{on "focusin" @controller.scrollInputIntoView}}
              />
              <label class="alt-placeholder" for="new-account-email">
                {{i18n "user.email.title"}}
              </label>
              {{#if @controller.showEmailValidation}}
                <DInputTip
                  id="account-email-validation"
                  @validation={{@controller.emailValidation}}
                />
              {{else}}
                <span class="more-info" id="account-email-validation-more-info">
                  {{#if
                    @controller.siteSettings.show_signup_form_email_instructions
                  }}
                    {{i18n "user.email.instructions"}}
                  {{/if}}
                </span>
              {{/if}}

              <PluginOutlet
                @name="create-account-after-email"
                @outletArgs={{lazyHash accountEmail=@controller.accountEmail}}
              />
            </div>

            <div class="input-group create-account__username">
              <input
                aria-describedby="username-validation username-validation-more-info"
                aria-invalid={{@controller.usernameValidation.failed}}
                autocomplete="off"
                class={{valueEntered @controller.accountUsername}}
                disabled={{@controller.usernameDisabled}}
                id="new-account-username"
                maxlength={{@controller.maxUsernameLength}}
                name="username"
                type="text"
                value={{@controller.accountUsername}}
                {{on "focusin" @controller.scrollInputIntoView}}
                {{on "input" @controller.setAccountUsername}}
              />
              <label class="alt-placeholder" for="new-account-username">
                {{i18n "user.username.title"}}
              </label>

              {{#if @controller.showUsernameInstructions}}
                <span class="more-info" id="username-validation-more-info">
                  {{i18n "user.username.instructions"}}
                </span>

              {{else}}
                <DInputTip
                  id="username-validation"
                  @validation={{@controller.usernameValidation}}
                />
              {{/if}}

              <PluginOutlet
                @name="create-account-after-username"
                @outletArgs={{lazyHash
                  accountUsername=@controller.accountUsername
                }}
              />
            </div>

            {{#if (and @controller.showFullname @controller.fullnameRequired)}}
              <FullnameInput
                class="input-group create-account__fullname required"
                @accountName={{@controller.accountName}}
                @nameDisabled={{@controller.nameDisabled}}
                @nameTitle={{@controller.nameTitle}}
                @nameValidation={{@controller.nameValidation}}
                @onFocusIn={{@controller.scrollInputIntoView}}
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
                <DPasswordField
                  aria-describedby="password-validation password-validation-more-info"
                  aria-invalid={{@controller.passwordValidation.failed}}
                  autocomplete="current-password"
                  class={{valueEntered @controller.accountPassword}}
                  id="new-account-password"
                  type={{if @controller.maskPassword "password" "text"}}
                  @capsLockOn={{@controller.capsLockOn}}
                  @value={{@controller.accountPassword}}
                  {{on "focusin" @controller.scrollInputIntoView}}
                />
                <label class="alt-placeholder" for="new-account-password">
                  {{i18n "user.password.title"}}
                </label>
                <DTogglePasswordMask
                  @maskPassword={{@controller.maskPassword}}
                  @togglePasswordMask={{@controller.togglePasswordMask}}
                />
                <div class="create-account__password-info">
                  <div class="create-account__password-tip-validation">
                    {{#if @controller.showPasswordValidation}}
                      <DInputTip
                        id="password-validation"
                        @validation={{@controller.passwordValidation}}
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
                      class={{dConcatClass
                        "caps-lock-warning"
                        (unless @controller.capsLockOn "hidden")
                      }}
                    >
                      {{dIcon "triangle-exclamation"}}
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
                  @autocomplete="new-password"
                  @id="new-account-confirmation"
                  @value={{@controller.accountHoneypot}}
                />
                <Input
                  id="new-account-challenge"
                  @value={{@controller.accountChallenge}}
                />
              </div>
            </div>

            {{#if @controller.requireInviteCode}}
              <div class="input-group create-account__invite-code">
                <Input
                  class={{valueEntered @controller.inviteCode}}
                  id="inviteCode"
                  @value={{@controller.inviteCode}}
                  {{on "focusin" @controller.scrollInputIntoView}}
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
              (and @controller.showFullname (not @controller.fullnameRequired))
            }}
              <FullnameInput
                class="input-group create-account__fullname"
                @accountName={{@controller.accountName}}
                @nameDisabled={{@controller.nameDisabled}}
                @nameTitle={{@controller.nameTitle}}
                @nameValidation={{@controller.nameValidation}}
                @onFocusIn={{@controller.scrollInputIntoView}}
              />
              <PluginOutlet
                @name="create-account-after-fullname"
                @outletArgs={{lazyHash accountName=@controller.accountName}}
              />
            {{/if}}

            {{#if @controller.userFields}}
              <div class="user-fields">
                {{#each @controller.userFields as |f|}}
                  <div class="input-group">
                    <UserField
                      class={{valueEntered f.value}}
                      @field={{f.field}}
                      @validation={{f.validation}}
                      @value={{f.value}}
                      {{on "focusin" @controller.scrollInputIntoView}}
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

          <SignupPageCta
            @createAccount={{@controller.createAccount}}
            @disclaimerHtml={{@controller.disclaimerHtml}}
            @formSubmitted={{@controller.formSubmitted}}
            @goToLogin={{@controller.goToLogin}}
            @hasAuthOptions={{@controller.hasAuthOptions}}
            @submitDisabled={{@controller.submitDisabled}}
          />
        {{/if}}

        {{#if @controller.skipConfirmation}}
          {{dLoadingSpinner size="large"}}
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
            @context="create-account"
            @externalLogin={{@controller.externalLogin}}
          />
        </div>
      {{/if}}
    </div>
  </div>
</template>
