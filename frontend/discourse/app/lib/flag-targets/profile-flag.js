import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { getAbsoluteURL } from "discourse/lib/get-url";
import { userPath } from "discourse/lib/url";
import { escapeExpression } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

export default class ProfileFlag {
  static pathFor(user) {
    return userPath(encodeURIComponent(user.username));
  }

  supportsPostActions = false;
  #flags;

  constructor(flags = []) {
    this.#flags = flags.map((flag) => {
      const description = flag.system
        ? i18n(`flagging_profile.description.${flag.name_key}`)
        : flag.description;
      return {
        id: flag.id,
        name_key: flag.name_key,
        name: flag.name,
        isIllegal: flag.isIllegal,
        enabled: flag.enabled,
        require_message: flag.require_message,
        description,
        short_description: description,
      };
    });
  }

  anonymousFlagDescription(user, email) {
    return i18n("flagging_profile.anonymous_description", {
      email: escapeExpression(email),
      subject: encodeURIComponent(i18n("anonymous_flagging.title")),
      url: encodeURIComponent(getAbsoluteURL(ProfileFlag.pathFor(user))),
    });
  }

  flagsAvailable() {
    return this.#flags;
  }

  title() {
    return "flagging_profile.action";
  }

  submitLabel() {
    return "flagging_profile.action";
  }

  customSubmitLabel() {
    return this.submitLabel();
  }

  async create(modal, { message }) {
    const { flagModel: user, onFlagged } = modal.args.model;
    modal.args.closeModal();

    try {
      await ajax(`/u/${encodeURIComponent(user.username)}/profile-flags`, {
        type: "POST",
        data: {
          flag_type_id: modal.selected.id,
          message,
          ...(modal.selected.isIllegal && { confirmed: modal.isConfirmed }),
        },
      });
      onFlagged();
      return true;
    } catch (error) {
      popupAjaxError(error);
      return false;
    }
  }
}
