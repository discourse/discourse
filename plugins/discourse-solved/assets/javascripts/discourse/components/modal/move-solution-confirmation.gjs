import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
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
      @closeModal={{this.cancel}}
      @title={{i18n "solved.confirm_move_solution_title"}}
      class="move-solution-confirmation-modal"
    >
      <:body>
        <p>{{i18n "solved.confirm_move_solution" count=@model.count}}</p>
        <div class="control-group">
          <label class="checkbox-label move-solution-dont-show-again">
            <Input
              @type="checkbox"
              @checked={{this.dontShowAgain}}
              {{on "change" this.toggleDontShowAgain}}
            />
            {{i18n "solved.dont_show_again"}}
          </label>
        </div>
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
          class="btn-transparent"
        />
      </:footer>
    </DModal>
  </template>
}
