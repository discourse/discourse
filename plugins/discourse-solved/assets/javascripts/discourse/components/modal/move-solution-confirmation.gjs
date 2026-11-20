import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default class MoveSolutionConfirmationModal extends Component {
  @tracked dontShowAgain = false;

  get confirmLabel() {
    return this.args.model.count > 1
      ? "solved.move_post_confirm.other"
      : "solved.move_post_confirm.one";
  }

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
      class="move-solution-confirmation-modal"
      @closeModal={{this.cancel}}
      @title={{i18n "solved.confirm_move_solution_title"}}
    >
      <:body>
        <p>{{i18n "solved.confirm_move_solution" count=@model.count}}</p>
        <div class="control-group">
          <label class="checkbox-label move-solution-dont-show-again">
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
          @label={{this.confirmLabel}}
        />
        <DButton
          class="btn-transparent"
          @action={{this.cancel}}
          @label="solved.move_post_cancel"
        />
      </:footer>
    </DModal>
  </template>
}
