import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { extractError } from "discourse/lib/ajax-error";

const DESCRIPTION_MAX_LENGTH = 280;

export default class ChatModalEditChannelDescription extends Component {
  @service chatApi;

  @tracked editedDescription = this.channel.description || "";
  @tracked flash;

  get channel() {
    return this.args.model;
  }

  get isSaveDisabled() {
    return (
      this.channel.description === this.editedDescription ||
      this.editedDescription?.length > DESCRIPTION_MAX_LENGTH
    );
  }

  get descriptionMaxLength() {
    return DESCRIPTION_MAX_LENGTH;
  }

  @action
  async onSaveChatChannelDescription() {
    try {
      const result = await this.chatApi.updateChannel(this.channel.id, {
        description: this.editedDescription,
      });
      this.channel.description = result.channel.description;
      this.args.closeModal();
    } catch (error) {
      this.flash = extractError(error);
    }
  }

  @action
  onChangeChatChannelDescription(description) {
    this.flash = null;
    this.editedDescription = description;
  }
}

<DModal
  @closeModal={{@closeModal}}
  class="chat-modal-edit-channel-description"
  @inline={{@inline}}
  @title={{i18n "chat.channel_edit_description_modal.title"}}
  @flash={{this.flash}}
>
  <:body>
    <span class="chat-modal-edit-channel-description__description">{{i18n
        "chat.channel_edit_description_modal.description"
      }}</span>
    <CharCounter
      @value={{this.editedDescription}}
      @max={{this.descriptionMaxLength}}
    >
      <textarea
        {{on "input" (with-event-value this.onChangeChatChannelDescription)}}
        class="chat-modal-edit-channel-description__description-input"
        placeholder={{i18n
          "chat.channel_edit_description_modal.input_placeholder"
        }}
      >{{this.editedDescription}}</textarea>
    </CharCounter>
  </:body>
  <:footer>
    <DButton
      @action={{this.onSaveChatChannelDescription}}
      @label="save"
      @disabled={{this.isSaveDisabled}}
      class="btn-primary create"
    />
    <DModalCancel @close={{@closeModal}} />
  </:footer>
</DModal>