import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import DModalCancel from "discourse/components/d-modal-cancel";
import { popupAjaxError } from "discourse/lib/ajax-error";
import i18n from "discourse-common/helpers/i18n";

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

  get multipleMessages() {
    return this.args.model.selectedMessageIds.length > 1;
  }

  <template>
    <DModal @closeModal={{@closeModal}} @headerClass="hidden">
      <:body>
        {{#if this.multipleMessages}}
          {{i18n
            "chat.delete_messages.confirm.other"
            count=@model.selectedMessageIds.length
          }}
        {{else}}
          {{i18n "chat.delete_messages.confirm.one"}}
        {{/if}}
      </:body>
      <:footer>
        <DButton
          class="btn-primary"
          @action={{this.delete}}
          @label="delete"
          @icon="trash-alt"
        />
        <DModalCancel @close={{@closeModal}} />
      </:footer>
    </DModal>
  </template>
}
