import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { isEmpty } from "@ember/utils";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import withEventValue from "discourse/helpers/with-event-value";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseLater from "discourse-common/lib/later";
import { i18n } from "discourse-i18n";

export default class ChatModalDeleteChannel extends Component {
  @service chatApi;
  @service router;

  @tracked channelNameConfirmation;
  @tracked deleting = false;
  @tracked confirmed = false;
  @tracked flash;
  @tracked flashType;

  get channel() {
    return this.args.model.channel;
  }

  get buttonDisabled() {
    if (this.deleting || this.confirmed) {
      return true;
    }

    if (
      isEmpty(this.channelNameConfirmation) ||
      this.channelNameConfirmation.toLowerCase() !==
        this.channel.title.toLowerCase()
    ) {
      return true;
    }

    return false;
  }

  get instructionsText() {
    return htmlSafe(
      i18n("chat.channel_delete.instructions", {
        name: this.channel.escapedTitle,
      })
    );
  }

  @action
  deleteChannel() {
    this.deleting = true;

    return this.chatApi
      .destroyChannel(this.channel.id, this.channelNameConfirmation)
      .then(() => {
        this.confirmed = true;
        this.flash = i18n("chat.channel_delete.process_started");
        this.flashType = "success";

        discourseLater(() => {
          this.args.closeModal();
          this.router.transitionTo("chat");
        }, 3000);
      })
      .catch(popupAjaxError)
      .finally(() => (this.deleting = false));
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      class="chat-modal-delete-channel"
      @inline={{@inline}}
      @title={{i18n "chat.channel_delete.title"}}
      @flash={{this.flash}}
      @flashType={{this.flashType}}
    >
      <:body>
        <p class="chat-modal-delete-channel__instructions">
          {{this.instructionsText}}
        </p>
        <input
          {{on
            "input"
            (withEventValue (fn (mut this.channelNameConfirmation)))
          }}
          id="channel-delete-confirm-name"
          placeholder={{i18n "chat.channel_delete.confirm_channel_name"}}
          autocorrect="off"
          autocapitalize="off"
          type="text"
        />
      </:body>
      <:footer>
        <DButton
          @disabled={{this.buttonDisabled}}
          @action={{this.deleteChannel}}
          @label="chat.channel_delete.confirm"
          id="chat-confirm-delete-channel"
          class="btn-danger"
        />
        <DButton @label="cancel" @action={{@closeModal}} class="btn-flat" />
      </:footer>
    </DModal>
  </template>
}
