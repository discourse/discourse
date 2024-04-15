import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { popupAjaxError } from "discourse/lib/ajax-error";
import i18n from "discourse-common/helpers/i18n";

export default class ChatModalThreadSettings extends Component {
  @service chatApi;

  @tracked editedTitle = this.thread.title || "";
  @tracked saving = false;

  get buttonDisabled() {
    return this.saving;
  }

  get thread() {
    return this.args.model;
  }

  @action
  saveThread() {
    this.saving = true;

    this.chatApi
      .editThread(this.thread.channel.id, this.thread.id, {
        title: this.editedTitle,
      })
      .then(() => {
        this.thread.title = this.editedTitle;
        this.args.closeModal();
      })
      .catch(popupAjaxError)
      .finally(() => {
        this.saving = false;
      });
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      class="chat-modal-thread-settings"
      @inline={{@inline}}
      @title={{i18n "chat.thread.settings"}}
    >
      <:body>
        <label for="thread-title" class="thread-title-label">
          {{i18n "chat.thread.title"}}
        </label>
        <Input
          name="thread-title"
          class="chat-modal-thread-settings__title-input"
          @type="text"
          @value={{this.editedTitle}}
        />
      </:body>
      <:footer>
        <DButton
          @disabled={{this.buttonDisabled}}
          @action={{this.saveThread}}
          @label="save"
          class="btn-primary"
        />
      </:footer>
    </DModal>
  </template>
}
