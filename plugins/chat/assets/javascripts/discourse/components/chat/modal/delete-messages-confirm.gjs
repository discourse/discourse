import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import DModalCancel from "discourse/components/d-modal-cancel";
import { popupAjaxError } from "discourse/lib/ajax-error";
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
