import { hash } from "@ember/helper";
import { htmlSafe } from "@ember/template";
import RouteTemplate from "ember-route-template";
import { and } from "truth-helpers";
import FlashMessage from "discourse/components/flash-message";
import LocalLoginForm from "discourse/components/local-login-form";
import LoginButtons from "discourse/components/login-buttons";
import LoginPageCta from "discourse/components/login-page-cta";
import PluginOutlet from "discourse/components/plugin-outlet";
import WelcomeHeader from "discourse/components/welcome-header";
import bodyClass from "discourse/helpers/body-class";
import concatClass from "discourse/helpers/concat-class";
import hideApplicationHeaderButtons from "discourse/helpers/hide-application-header-buttons";
import hideApplicationSidebar from "discourse/helpers/hide-application-sidebar";
import lazyHash from "discourse/helpers/lazy-hash";
import loadingSpinner from "discourse/helpers/loading-spinner";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    {{hideApplicationHeaderButtons "search" "login" "signup" "menu"}}
    {{hideApplicationSidebar}}
    {{bodyClass "login-page"}}

    {{#if @controller.isRedirectingToExternalAuth}}
      {{! Hide the login form if the site has only one external }}
      {{! authentication method and is being automatically redirected to it }}
      {{loadingSpinner}}
    {{else}}
      <div class="login-fullpage">
        <FlashMessage
          @flash={{@controller.flash}}
          @type={{@controller.flashType}}
        />

        <div class={{concatClass "login-body" @controller.bodyClasses}}>
          <PluginOutlet
            @name="login-before-modal-body"
            @connectorTagName="div"
            @outletArgs={{lazyHash
              flashChanged=this.flashChanged
              flashTypeChanged=this.flashTypeChanged
            }}
          />

          {{#if @controller.hasNoLoginOptions}}
            <div class={{if @controller.site.desktopView "login-left-side"}}>
              <div class="login-welcome-header no-login-methods-configured">
                <h1 class="login-title">{{i18n
                    "login.no_login_methods.title"
                  }}</h1>
                <img />
                <p class="login-subheader">
                  {{htmlSafe
                    (i18n
                      "login.no_login_methods.description"
                      (hash adminLoginPath=@controller.adminLoginPath)
                    )
                  }}
                </p>
              </div>
            </div>
          {{else}}
            {{#if @controller.site.mobileView}}
              <WelcomeHeader @header={{i18n "login.header_title"}}>
                <PluginOutlet
                  @name="login-header-bottom"
                  @outletArgs={{lazyHash
                    createAccount=@controller.createAccount
                  }}
                />
              </WelcomeHeader>
              {{#if @controller.showLoginButtons}}
                <LoginButtons
                  @externalLogin={{@controller.externalLoginAction}}
                  @passkeyLogin={{@controller.passkeyLogin}}
                  @context="login"
                />
              {{/if}}
            {{/if}}

            {{#if @controller.canLoginLocal}}
              <div class={{if @controller.site.desktopView "login-left-side"}}>
                {{#if @controller.site.desktopView}}
                  <WelcomeHeader @header={{i18n "login.header_title"}}>
                    <PluginOutlet
                      @name="login-header-bottom"
                      @outletArgs={{lazyHash
                        createAccount=@controller.createAccount
                      }}
                    />
                  </WelcomeHeader>
                {{/if}}
                <LocalLoginForm
                  @loginName={{@controller.loginName}}
                  @loginNameChanged={{@controller.loginNameChanged}}
                  @canLoginLocalWithEmail={{@controller.canLoginLocalWithEmail}}
                  @canUsePasskeys={{@controller.canUsePasskeys}}
                  @passkeyLogin={{@controller.passkeyLogin}}
                  @loginPassword={{@controller.loginPassword}}
                  @secondFactorMethod={{@controller.secondFactorMethod}}
                  @secondFactorToken={{@controller.secondFactorToken}}
                  @backupEnabled={{@controller.backupEnabled}}
                  @totpEnabled={{@controller.totpEnabled}}
                  @securityKeyAllowedCredentialIds={{@controller.securityKeyAllowedCredentialIds}}
                  @securityKeyChallenge={{@controller.securityKeyChallenge}}
                  @showSecurityKey={{@controller.showSecurityKey}}
                  @otherMethodAllowed={{@controller.otherMethodAllowed}}
                  @showSecondFactor={{@controller.showSecondFactor}}
                  @handleForgotPassword={{@controller.handleForgotPassword}}
                  @login={{@controller.triggerLogin}}
                  @flashChanged={{@controller.flashChanged}}
                  @flashTypeChanged={{@controller.flashTypeChanged}}
                  @securityKeyCredentialChanged={{@controller.securityKeyCredentialChanged}}
                />
                {{#if @controller.site.desktopView}}
                  <LoginPageCta
                    @canLoginLocal={{@controller.canLoginLocal}}
                    @showSecurityKey={{@controller.showSecurityKey}}
                    @login={{@controller.triggerLogin}}
                    @loginButtonLabel={{@controller.loginButtonLabel}}
                    @loginDisabled={{@controller.loginDisabled}}
                    @showSignupLink={{@controller.showSignupLink}}
                    @createAccount={{@controller.createAccount}}
                    @loggingIn={{@controller.loggingIn}}
                    @showSecondFactor={{@controller.showSecondFactor}}
                  />
                {{/if}}
              </div>
            {{/if}}

            {{#if
              (and @controller.showLoginButtons @controller.site.desktopView)
            }}
              {{#unless @controller.canLoginLocal}}
                <div class="login-left-side">
                  <WelcomeHeader @header={{i18n "login.header_title"}} />
                </div>
              {{/unless}}
              {{#if @controller.hasAtLeastOneLoginButton}}
                <div class="login-right-side">
                  <LoginButtons
                    @externalLogin={{@controller.externalLoginAction}}
                    @passkeyLogin={{@controller.passkeyLogin}}
                    @context="login"
                  />
                </div>
              {{/if}}
            {{/if}}
          {{/if}}

          {{#if @controller.site.mobileView}}
            {{#unless @controller.hasNoLoginOptions}}
              <LoginPageCta
                @canLoginLocal={{@controller.canLoginLocal}}
                @showSecurityKey={{@controller.showSecurityKey}}
                @login={{@controller.triggerLogin}}
                @loginButtonLabel={{@controller.loginButtonLabel}}
                @loginDisabled={{@controller.loginDisabled}}
                @showSignupLink={{@controller.showSignupLink}}
                @createAccount={{@controller.createAccount}}
                @loggingIn={{@controller.loggingIn}}
                @showSecondFactor={{@controller.showSecondFactor}}
              />
            {{/unless}}
          {{/if}}
        </div>
        <PluginOutlet @name="below-login-page" />
      </div>
    {{/if}}
  </template>
);
