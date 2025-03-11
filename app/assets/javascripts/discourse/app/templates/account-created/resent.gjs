import RouteTemplate from 'ember-route-template'
import SignupProgressBar from "discourse/components/signup-progress-bar";
import htmlSafe from "discourse/helpers/html-safe";
import i18n from "discourse/helpers/i18n";
export default RouteTemplate(<template><SignupProgressBar @step="activate" />
<div class="ac-message">
  {{#if @controller.email}}
    {{htmlSafe (i18n "login.sent_activation_email_again" currentEmail=@controller.email)}}
  {{else}}
    {{i18n "login.sent_activation_email_again_generic"}}
  {{/if}}
</div></template>)