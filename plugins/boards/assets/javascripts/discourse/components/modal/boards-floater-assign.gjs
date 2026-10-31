import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import legacyPickOne from "discourse/lib/legacy-pick-one";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import DSelectUser from "discourse/ui-kit/select/recipes/users/d-select-user";
import { i18n } from "discourse-i18n";

export default class BoardsFloaterAssign extends Component {
  @service siteSettings;

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
      class="discourse-boards-floater-assign-modal"
      @closeModal={{@closeModal}}
      @title={{i18n "boards.board.assign_card"}}
    >
      <:body>
        {{! TODO (select-kit-replacement-cleanup) }}
        {{#if this.siteSettings.enable_new_select_controls}}
          <DSelectUser
            @clearable={{true}}
            @onChange={{legacyPickOne this.onAssigneeChanged}}
            @texts={{hash ariaLabel=(i18n "boards.board.assigned_to")}}
            @value={{this.assignee}}
          />
        {{else}}
          {{! TODO (select-kit-replacement-cleanup) }}
          <EmailGroupUserChooser
            @onChange={{this.onAssigneeChanged}}
            @options={{hash maximum=1 excludeCurrentUser=false}}
            @value={{this.assignee}}
          />
        {{/if}}
      </:body>
      <:footer>
        <DButton class="btn-primary" @action={{this.save}} @label="save" />
      </:footer>
    </DModal>
  </template>
}
