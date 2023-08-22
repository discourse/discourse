import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";

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
  onSaveChatChannelDescription() {
    return this.chatApi
      .updateChannel(this.channel.id, { description: this.editedDescription })
      .then((result) => {
        this.channel.description = result.channel.description;
        this.args.closeModal();
      })
      .catch((event) => {
        if (event.jqXHR?.responseJSON?.errors) {
          this.flash = event.jqXHR.responseJSON.errors.join("\n");
        }
      });
  }

  @action
  onChangeChatChannelDescription(description) {
    this.flash = null;
    this.editedDescription = description;
  }
}
