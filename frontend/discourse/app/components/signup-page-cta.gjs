import { trustHTML } from "@ember/template";
import PluginOutlet from "discourse/components/plugin-outlet";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

const SignupPageCta = <template>
  <div class="signup-page-cta">
    {{#if @disclaimerHtml}}
      <div class="signup-page-cta__disclaimer">
        {{trustHTML @disclaimerHtml}}
      </div>
    {{/if}}
    <div class="signup-page-cta__buttons">
      <DButton
        class="btn-large btn-primary signup-page-cta__signup"
        @action={{@createAccount}}
        @disabled={{@submitDisabled}}
        @isLoading={{@formSubmitted}}
        @label="create_account.title"
      />
      {{#unless @hasAuthOptions}}
        <span class="signup-page-cta__existing-account">
          {{i18n "create_account.already_have_account"}}
        </span>
        <DButton
          class="btn-large btn-flat signup-page-cta__login"
          @action={{@goToLogin}}
          @disabled={{@formSubmitted}}
          @label="log_in"
        />
      {{/unless}}
    </div>
  </div>
  <PluginOutlet
    @connectorTagName="div"
    @name="create-account-after-modal-footer"
  />
</template>;

export default SignupPageCta;
