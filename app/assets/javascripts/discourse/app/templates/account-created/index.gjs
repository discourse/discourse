import RouteTemplate from 'ember-route-template'
import SignupProgressBar from "discourse/components/signup-progress-bar";
import WelcomeHeader from "discourse/components/welcome-header";
import htmlSafe from "discourse/helpers/html-safe";
import ActivationControls from "discourse/components/activation-controls";
export default RouteTemplate(<template><SignupProgressBar @step="activate" />
<WelcomeHeader @header={{@controller.welcomeTitle}} />
<div class="success-info">
  {{htmlSafe @controller.accountCreated.message}}
</div>
{{#if @controller.accountCreated.show_controls}}
  <ActivationControls @sendActivationEmail={{action "sendActivationEmail"}} @editActivationEmail={{action "editActivationEmail"}} />
{{/if}}</template>)