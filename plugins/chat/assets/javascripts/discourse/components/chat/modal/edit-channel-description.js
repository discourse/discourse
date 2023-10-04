import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";
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
