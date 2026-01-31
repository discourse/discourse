import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { i18n } from "discourse-i18n";

export default class MoveSolutionConfirmationModal extends Component {
  @tracked dontShowAgain = false;

  get message() {
    return htmlSafe(
      i18n("solved.confirm_move_solution", { count: this.args.model.count })
    );
  }

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
      @closeModal={{this.cancel}}
      @title={{i18n "solved.confirm_move_solution_title"}}
      class="move-solution-confirmation-modal"
    >
      <:body>
        <p>{{this.message}}</p>
        <label class="move-solution-dont-show-again">
          <input
            type="checkbox"
            checked={{this.dontShowAgain}}
            {{on "change" this.toggleDontShowAgain}}
          />
          {{i18n "solved.dont_show_again"}}
        </label>
      </:body>
      <:footer>
        <DButton
          @action={{this.confirm}}
          @label={{this.confirmLabel}}
          class="btn-primary"
        />
        <DButton
          @action={{this.cancel}}
          @label="solved.move_post_cancel"
          class="btn-default"
        />
      </:footer>
    </DModal>
  </template>
}
