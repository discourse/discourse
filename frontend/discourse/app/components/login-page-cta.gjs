import DButton from "discourse/components/d-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import { i18n } from "discourse-i18n";

const LoginPageCta = <template>
  <div class="login-page-cta">
    <div class="login-page-cta__buttons">
      {{#if @canLoginLocal}}
        {{#unless @showSecurityKey}}
          <DButton
            @action={{@login}}
            @disabled={{@loginDisabled}}
            @isLoading={{@loggingIn}}
            @label={{@loginButtonLabel}}
            id="login-button"
            form="login-form"
            class="btn-large btn-primary login-page-cta__login"
            tabindex={{unless @showSecondFactor "2"}}
          />
        {{/unless}}

        {{#if @showSignupLink}}
          <span class="login-page-cta__no-account-yet">
            {{i18n "create_account.no_account_yet"}}
          </span>
          <DButton
            @action={{@createAccount}}
            @disabled={{@loggingIn}}
            @label="create_account.title"
            class="btn-large btn-flat login-page-cta__signup"
            id="new-account-link"
            tabindex="3"
          />
        {{/if}}
      {{/if}}
    </div>
    <PluginOutlet @name="login-after-modal-footer" @connectorTagName="div" />
  </div>
</template>;

export default LoginPageCta;
