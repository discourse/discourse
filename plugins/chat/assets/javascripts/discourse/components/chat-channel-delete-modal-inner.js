import Component from "@ember/component";
import { isEmpty } from "@ember/utils";
import I18n from "I18n";
import discourseComputed from "discourse-common/utils/decorators";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseLater from "discourse-common/lib/later";
import { htmlSafe } from "@ember/template";
import Modal from "discourse/controllers/modal";

export default Component.extend(ModalFunctionality, {
  chat: service(),
  chatApi: service(),
  router: service(),
  tagName: "",
  chatChannel: null,
  channelNameConfirmation: null,
  deleting: false,
  confirmed: false,

  @discourseComputed("deleting", "channelNameConfirmation", "confirmed")
  buttonDisabled(deleting, channelNameConfirmation, confirmed) {
    if (deleting || confirmed) {
      return true;
    }

    if (
      isEmpty(channelNameConfirmation) ||
      channelNameConfirmation.toLowerCase() !==
        this.chatChannel.title.toLowerCase()
    ) {
      return true;
    }
    return false;
  },

  @action
  deleteChannel() {
    this.set("deleting", true);

    return this.chatApi
      .destroyChannel(this.chatChannel.id, this.channelNameConfirmation)
      .then(() => {
        this.set("confirmed", true);
        this.flash(I18n.t("chat.channel_delete.process_started"), "success");

        discourseLater(() => {
          this.closeModal();
          this.router.transitionTo("chat");
        }, 3000);
      })
      .catch(popupAjaxError)
      .finally(() => this.set("deleting", false));
  },

  @discourseComputed()
  instructionsText() {
    return htmlSafe(
      I18n.t("chat.channel_delete.instructions", {
        name: this.chatChannel.escapedTitle,
      })
    );
  },
});
