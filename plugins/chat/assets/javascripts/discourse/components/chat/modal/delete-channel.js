import Component from "@glimmer/component";
import { isEmpty } from "@ember/utils";
import I18n from "I18n";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseLater from "discourse-common/lib/later";
import { htmlSafe } from "@ember/template";
import { tracked } from "@glimmer/tracking";

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
      I18n.t("chat.channel_delete.instructions", {
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
        this.flash = I18n.t("chat.channel_delete.process_started");
        this.flashType = "success";

        discourseLater(() => {
          this.args.closeModal();
          this.router.transitionTo("chat");
        }, 3000);
      })
      .catch(popupAjaxError)
      .finally(() => (this.deleting = false));
  }
}
