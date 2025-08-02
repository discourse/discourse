import Component from "@glimmer/component";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { i18n } from "discourse-i18n";

export default class GroupDefaultNotifications extends Component {
  @action
  updateExistingUsers() {
    this.args.model.setUpdateExistingUsers(true);
    this.args.closeModal();
  }

  @action
  cancel() {
    this.args.model.setUpdateExistingUsers(false);
    this.args.closeModal();
  }

  <template>
    <DModal
      @title={{i18n "groups.default_notifications.modal_title"}}
      @closeModal={{@closeModal}}
    >
      <:body>
        {{i18n
          "groups.default_notifications.modal_description"
          count=@model.count
        }}
      </:body>
      <:footer>
        <DButton
          @action={{this.updateExistingUsers}}
          @label="groups.default_notifications.modal_yes"
          class="btn-primary"
        />
        <DButton
          @action={{this.cancel}}
          @label="groups.default_notifications.modal_no"
        />
      </:footer>
    </DModal>
  </template>
}
