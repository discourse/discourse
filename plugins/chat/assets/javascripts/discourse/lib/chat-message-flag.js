import { setOwner } from "@ember/owner";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import getURL from "discourse-common/lib/get-url";
import { i18n } from "discourse-i18n";

export default class ChatMessageFlag {
  @service chatApi;

  constructor(owner) {
    setOwner(this, owner);
  }

  title() {
    return "flagging.title";
  }

  customSubmitLabel() {
    return "flagging.notify_action";
  }

  submitLabel() {
    return "chat.flagging.action";
  }

  targetsTopic() {
    return false;
  }

  editable() {
    return false;
  }

  _rewriteFlagDescriptions(flags) {
    return flags.map((flag) => {
      flag.set(
        "description",
        i18n(`chat.flags.${flag.name_key}`, {
          basePath: getURL(""),
          defaultValue: flag.description,
        })
      );
      return flag;
    });
  }

  flagsAvailable(flagModal) {
    let flagsAvailable = flagModal.site.flagTypes;

    flagsAvailable = flagsAvailable.filter((flag) => {
      return (
        flagModal.args.model.flagModel.availableFlags.includes(flag.name_key) &&
        flag.applies_to.includes("Chat::Message")
      );
    });

    // "message user" option should be at the top
    const notifyUserIndex = flagsAvailable.indexOf(
      flagsAvailable.filterBy("name_key", "notify_user")[0]
    );

    if (notifyUserIndex !== -1) {
      const notifyUser = flagsAvailable[notifyUserIndex];
      flagsAvailable.splice(notifyUserIndex, 1);
      flagsAvailable.splice(0, 0, notifyUser);
    }

    return this._rewriteFlagDescriptions(flagsAvailable);
  }

  async create(flagModal, opts) {
    flagModal.args.closeModal();

    const channelId = flagModal.args.model.flagModel.channel.id;
    const messageId = flagModal.args.model.flagModel.id;

    try {
      await this.chatApi.flagMessage(channelId, messageId, {
        flag_type_id: flagModal.selected.id,
        message: opts.message,
        is_warning: opts.isWarning,
        take_action: opts.takeAction,
        queue_for_review: opts.queue_for_review,
      });
    } catch (error) {
      popupAjaxError(error);
    }
  }
}
