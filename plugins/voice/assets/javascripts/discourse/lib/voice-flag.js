import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class VoiceFlag {
  constructor(room) {
    this.room = room;
  }

  title() {
    return "flagging.title";
  }

  customSubmitLabel() {
    return "flagging.notify_action";
  }

  submitLabel() {
    return "flagging.action";
  }

  targetsTopic() {
    return false;
  }

  editable() {
    return false;
  }

  // A participant has no post or chat message to give the flag context, so
  // only the free-form "something else" flag is offered; a single option is
  // auto-selected by the modal.
  flagsAvailable(flagModal) {
    return flagModal.site.flagTypes
      .filter((flagType) => flagType.name_key === "notify_moderators")
      .map((flagType) => {
        flagType.set(
          "description",
          i18n("voice.flagging.notify_moderators_description", {
            defaultValue: flagType.description,
          })
        );
        return flagType;
      });
  }

  async create(flagModal, opts) {
    flagModal.args.closeModal();

    try {
      await ajax(`/voice/rooms/${this.room.id}/flag`, {
        type: "POST",
        data: {
          user_id: flagModal.args.model.flagModel.user_id,
          flag_type_id: flagModal.selected.id,
          message: opts.message,
        },
      });
    } catch (error) {
      popupAjaxError(error);
    }
  }
}
