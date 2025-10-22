import RouteTemplate from "ember-route-template";
import ActivationEmailForm from "discourse/components/activation-email-form";
import DButton from "discourse/components/d-button";
import SignupProgressBar from "discourse/components/signup-progress-bar";

export default RouteTemplate(
  <template>
    <SignupProgressBar @step="activate" />
    <div class="ac-message">
      <ActivationEmailForm
        @email={{@controller.newEmail}}
        @updateNewEmail={{@controller.updateNewEmail}}
      />
    </div>
    <div class="activation-controls">
      <DButton
        @action={{@controller.changeEmail}}
        @label="login.submit_new_email"
        @disabled={{@controller.submitDisabled}}
        class="btn-primary"
      />
      <DButton
        @action={{@controller.cancel}}
        @label="cancel"
        class="edit-cancel"
      />
    </div>
  </template>
);
