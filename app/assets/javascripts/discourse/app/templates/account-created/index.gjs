import { htmlSafe } from "@ember/template";
import RouteTemplate from "ember-route-template";
import ActivationControls from "discourse/components/activation-controls";
import SignupProgressBar from "discourse/components/signup-progress-bar";
import WelcomeHeader from "discourse/components/welcome-header";

export default RouteTemplate(
  <template>
    <SignupProgressBar @step="activate" />
    <WelcomeHeader @header={{@controller.welcomeTitle}} />
    <div class="success-info">
      {{htmlSafe @controller.accountCreated.message}}
    </div>
    {{#if @controller.accountCreated.show_controls}}
      <ActivationControls
        @sendActivationEmail={{@controller.sendActivationEmail}}
        @editActivationEmail={{@controller.editActivationEmail}}
      />
    {{/if}}
  </template>
);
