import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default class SolvedRemovalConfirmationModal extends Component {
  @tracked dontShowAgain = false;

  @action
  toggleDontShowAgain(event) {
    this.dontShowAgain = event.target.checked;
  }

  @action
  confirm() {
    this.args.closeModal({
      confirmed: true,
      dontShowAgain: this.dontShowAgain,
    });
  }

  @action
  cancel() {
    this.args.closeModal({ confirmed: false });
  }

  <template>
    <DModal
      class="solved-removal-confirmation-modal"
      @closeModal={{this.cancel}}
      @title={{i18n "solved.confirm_solved_removal_title"}}
    >
      <:body>
        <p>{{i18n "solved.confirm_solved_removal"}}</p>
        <div class="control-group">
          <label class="checkbox-label solved-removal-dont-show-again">
            <input
              checked={{this.dontShowAgain}}
              type="checkbox"
              {{on "change" this.toggleDontShowAgain}}
            />
            {{i18n "solved.dont_show_again"}}
          </label>
        </div>
      </:body>
      <:footer>
        <DButton
          class="btn-primary"
          @action={{this.confirm}}
          @label="solved.confirm_solved_removal_confirm"
        />
        <DButton
          class="btn-transparent"
          @action={{this.cancel}}
          @label="solved.confirm_solved_removal_cancel"
        />
      </:footer>
    </DModal>
  </template>
}
