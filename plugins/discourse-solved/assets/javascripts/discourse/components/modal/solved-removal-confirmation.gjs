import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
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
      @closeModal={{this.cancel}}
      @title={{i18n "solved.confirm_solved_removal_title"}}
      class="solved-removal-confirmation-modal"
    >
      <:body>
        <p>{{i18n "solved.confirm_solved_removal"}}</p>
        <div class="control-group">
          <label class="checkbox-label solved-removal-dont-show-again">
            <input
              type="checkbox"
              checked={{this.dontShowAgain}}
              {{on "change" this.toggleDontShowAgain}}
            />
            {{i18n "solved.dont_show_again"}}
          </label>
        </div>
      </:body>
      <:footer>
        <DButton
          @action={{this.confirm}}
          @label="solved.confirm_solved_removal_confirm"
          class="btn-primary"
        />
        <DButton
          @action={{this.cancel}}
          @label="solved.confirm_solved_removal_cancel"
          class="btn-transparent"
        />
      </:footer>
    </DModal>
  </template>
}
