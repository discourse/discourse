import Component from "@glimmer/component";
import { action } from "@ember/object";

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
}
<DModal
  @title={{i18n "groups.default_notifications.modal_title"}}
  @closeModal={{@closeModal}}
>
  <:body>
    {{i18n "groups.default_notifications.modal_description" count=@model.count}}
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