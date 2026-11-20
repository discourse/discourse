import ActivationEmailForm from "discourse/components/activation-email-form";
import SignupProgressBar from "discourse/components/signup-progress-bar";
import DButton from "discourse/ui-kit/d-button";

export default <template>
  <SignupProgressBar @step="activate" />
  <div class="ac-message">
    <ActivationEmailForm
      @email={{@controller.newEmail}}
      @updateNewEmail={{@controller.updateNewEmail}}
    />
  </div>
  <div class="activation-controls">
    <DButton
      class="btn-primary"
      @action={{@controller.changeEmail}}
      @disabled={{@controller.submitDisabled}}
      @label="login.submit_new_email"
    />
    <DButton
      class="edit-cancel"
      @action={{@controller.cancel}}
      @label="cancel"
    />
  </div>
</template>
