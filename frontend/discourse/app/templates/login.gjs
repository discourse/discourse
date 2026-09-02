import CodeLoginForm from "discourse/components/code-login-form";
import LocalLoginForm from "discourse/components/local-login-form";
import LoginButtons from "discourse/components/login-buttons";
import LoginPageCta from "discourse/components/login-page-cta";
import NoLoginMethods from "discourse/components/no-login-methods";
import PluginOutlet from "discourse/components/plugin-outlet";
import WelcomeHeader from "discourse/components/welcome-header";
import bodyClass from "discourse/helpers/body-class";
import hideApplicationHeaderButtons from "discourse/helpers/hide-application-header-buttons";
import hideApplicationSidebar from "discourse/helpers/hide-application-sidebar";
import lazyHash from "discourse/helpers/lazy-hash";
import { and, not } from "discourse/truth-helpers";
import DFlashMessage from "discourse/ui-kit/d-flash-message";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

export default <template>
  {{hideApplicationHeaderButtons "search" "login" "signup" "menu"}}
  {{hideApplicationSidebar}}
  {{bodyClass "login-page"}}

  <div class="login-fullpage">
    <DFlashMessage
      @flash={{@controller.flash}}
      @type={{@controller.flashType}}
    />

    <div class={{dConcatClass "login-body" @controller.bodyClasses}}>
      <PluginOutlet
        @connectorTagName="div"
        @name="login-before-modal-body"
        @outletArgs={{lazyHash
          flashChanged=this.flashChanged
          flashTypeChanged=this.flashTypeChanged
        }}
      />

      {{#if @controller.hasNoLoginOptions}}
        <div class={{if @controller.site.desktopView "login-left-side"}}>
          <NoLoginMethods />
        </div>
      {{else}}
        {{#if @controller.site.mobileView}}
          <WelcomeHeader @header={{i18n "login.header_title"}}>
            <PluginOutlet
              @name="login-header-bottom"
              @outletArgs={{lazyHash createAccount=@controller.createAccount}}
            />
          </WelcomeHeader>
          {{#if
            (and
              @controller.showLoginButtons (not @controller.showCodeLoginForm)
            )
          }}

            <LoginButtons
              @context="login"
              @externalLogin={{@controller.externalLogin}}
              @passkeyLogin={{@controller.passkeyLogin}}
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

            <PluginOutlet
              @name="login-wrapper"
              @outletArgs={{lazyHash externalLogin=@controller.externalLogin}}
            >
              {{#if @controller.showCodeLoginForm}}
                <CodeLoginForm
                  @initialEmail={{@controller.loginName}}
                  @onUsePassword={{@controller.usePassword}}
                />
              {{else}}
                <LocalLoginForm
                  @backupEnabled={{@controller.backupEnabled}}
                  @canLoginLocalWithEmail={{@controller.canLoginLocalWithEmail}}
                  @canUsePasskeys={{@controller.canUsePasskeys}}
                  @flashChanged={{@controller.flashChanged}}
                  @flashTypeChanged={{@controller.flashTypeChanged}}
                  @handleForgotPassword={{@controller.handleForgotPassword}}
                  @login={{@controller.localLogin}}
                  @loginName={{@controller.loginName}}
                  @loginNameChanged={{@controller.loginNameChanged}}
                  @loginPassword={{@controller.loginPassword}}
                  @loginPasswordChanged={{@controller.loginPasswordChanged}}
                  @onShowCodeLogin={{if
                    @controller.canUseCodeLogin
                    @controller.showCodeLogin
                  }}
                  @otherMethodAllowed={{@controller.otherMethodAllowed}}
                  @passkeyLogin={{@controller.passkeyLogin}}
                  @secondFactorMethod={{@controller.secondFactorMethod}}
                  @secondFactorToken={{@controller.secondFactorToken}}
                  @secondFactorTokenChanged={{@controller.secondFactorTokenChanged}}
                  @securityKeyAllowedCredentialIds={{@controller.securityKeyAllowedCredentialIds}}
                  @securityKeyChallenge={{@controller.securityKeyChallenge}}
                  @securityKeyCredentialChanged={{@controller.securityKeyCredentialChanged}}
                  @showSecondFactor={{@controller.showSecondFactor}}
                  @showSecurityKey={{@controller.showSecurityKey}}
                  @totpEnabled={{@controller.totpEnabled}}
                />
              {{/if}}
            </PluginOutlet>

            {{#if
              (and
                @controller.site.desktopView (not @controller.showCodeLoginForm)
              )
            }}
              <LoginPageCta
                @canLoginLocal={{@controller.canLoginLocal}}
                @createAccount={{@controller.createAccount}}
                @loggingIn={{@controller.loggingIn}}
                @login={{@controller.localLogin}}
                @loginButtonLabel={{@controller.loginButtonLabel}}
                @loginDisabled={{@controller.loginDisabled}}
                @showSecondFactor={{@controller.showSecondFactor}}
                @showSecurityKey={{@controller.showSecurityKey}}
                @showSignupLink={{@controller.showSignupLink}}
              />
            {{/if}}
          </div>
        {{/if}}

        {{#if
          (and
            @controller.showLoginButtons
            @controller.site.desktopView
            (not @controller.showCodeLoginForm)
          )
        }}

          {{#unless @controller.canLoginLocal}}
            <div class="login-left-side">
              <WelcomeHeader @header={{i18n "login.header_title"}} />
            </div>
          {{/unless}}
          {{#if @controller.hasAtLeastOneLoginButton}}
            <div class="login-right-side">
              <LoginButtons
                @context="login"
                @externalLogin={{@controller.externalLogin}}
                @passkeyLogin={{@controller.passkeyLogin}}
              />
            </div>
          {{/if}}

        {{/if}}
      {{/if}}

      {{#if
        (and @controller.site.mobileView (not @controller.showCodeLoginForm))
      }}
        {{#unless @controller.hasNoLoginOptions}}
          <LoginPageCta
            @canLoginLocal={{@controller.canLoginLocal}}
            @createAccount={{@controller.createAccount}}
            @loggingIn={{@controller.loggingIn}}
            @login={{@controller.localLogin}}
            @loginButtonLabel={{@controller.loginButtonLabel}}
            @loginDisabled={{@controller.loginDisabled}}
            @showSecondFactor={{@controller.showSecondFactor}}
            @showSecurityKey={{@controller.showSecurityKey}}
            @showSignupLink={{@controller.showSignupLink}}
          />
        {{/unless}}
      {{/if}}

    </div>
    <PluginOutlet @name="below-login-page" />
  </div>
</template>
