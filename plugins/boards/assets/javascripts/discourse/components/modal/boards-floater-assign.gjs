import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default class BoardsFloaterAssign extends Component {
  @tracked
  assignee = this.args.model.currentAssignee
    ? [this.args.model.currentAssignee]
    : [];

  @action
  onAssigneeChanged(value) {
    this.assignee = value || [];
  }

  @action
  async save() {
    await this.args.model.onSave(this.assignee[0] || null);
    this.args.closeModal();
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @title={{i18n "boards.board.assign_card"}}
      class="discourse-boards-floater-assign-modal"
    >
      <:body>
        <EmailGroupUserChooser
          @value={{this.assignee}}
          @onChange={{this.onAssigneeChanged}}
          @options={{hash maximum=1 excludeCurrentUser=false}}
        />
      </:body>
      <:footer>
        <DButton @action={{this.save}} @label="save" class="btn-primary" />
      </:footer>
    </DModal>
  </template>
}
