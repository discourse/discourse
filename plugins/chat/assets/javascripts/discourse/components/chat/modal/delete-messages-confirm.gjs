import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import DModalCancel from "discourse/ui-kit/d-modal-cancel";
import { i18n } from "discourse-i18n";

export default class DeleteMessagesConfirm extends Component {
  @service chatApi;

  @action
  async delete() {
    try {
      await this.chatApi.trashMessages(
        this.args.model.sourceChannel.id,
        this.args.model.selectedMessageIds
      );
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.args.closeModal();
    }
  }

  <template>
    <DModal @closeModal={{@closeModal}} @headerClass="hidden">
      <:body>
        {{i18n
          "chat.delete_messages.confirm"
          count=@model.selectedMessageIds.length
        }}
      </:body>
      <:footer>
        <DButton
          class="btn-primary"
          @action={{this.delete}}
          @label="delete"
          @icon="trash-can"
        />
        <DModalCancel @close={{@closeModal}} />
      </:footer>
    </DModal>
  </template>
}
