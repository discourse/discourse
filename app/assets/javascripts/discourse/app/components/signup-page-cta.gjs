import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import routeAction from "discourse/helpers/route-action";
import i18n from "discourse-common/helpers/i18n";

const SignupPageCta = <template>
  <div class="signup-page-cta">
    {{#if @disclaimerHtml}}
      <div class="signup-page-cta__disclaimer">
        {{htmlSafe @disclaimerHtml}}
      </div>
    {{/if}}
    <div class="signup-page-cta__buttons">
      <DButton
        @action={{@createAccount}}
        @disabled={{@submitDisabled}}
        @isLoading={{@formSubmitted}}
        @label="create_account.title"
        class="btn-large btn-primary signup-page-cta__signup"
      />
      {{#unless @hasAuthOptions}}
        <span class="signup-page-cta__existing-account">
          {{i18n "create_account.already_have_account"}}
        </span>
        <DButton
          @action={{routeAction "showLogin"}}
          @disabled={{@formSubmitted}}
          @label="log_in"
          class="btn-large btn-flat signup-page-cta__login"
        />
      {{/unless}}
    </div>
  </div>
  <PluginOutlet
    @name="create-account-after-modal-footer"
    @connectorTagName="div"
  />
</template>;

export default SignupPageCta;
