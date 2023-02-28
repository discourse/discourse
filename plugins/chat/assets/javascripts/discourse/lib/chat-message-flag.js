import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import I18n from "I18n";
import getURL from "discourse-common/lib/get-url";

export default class ChatMessageFlag {
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
        I18n.t(`chat.flags.${flag.name_key}`, { basePath: getURL("") })
      );
      return flag;
    });
  }

  flagsAvailable(_controller, site, model) {
    let flagsAvailable = site.flagTypes;

    flagsAvailable = flagsAvailable.filter((flag) => {
      return model.availableFlags.includes(flag.name_key);
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

  create(controller, opts) {
    controller.send("hideModal");

    return ajax("/chat/flag", {
      method: "PUT",
      data: {
        chat_message_id: controller.get("model.id"),
        flag_type_id: controller.get("selected.id"),
        message: opts.message,
        is_warning: opts.isWarning,
        take_action: opts.takeAction,
        queue_for_review: opts.queue_for_review,
      },
    })
      .then(() => {
        if (controller.isDestroying || controller.isDestroyed) {
          return;
        }

        if (!opts.skipClose) {
          controller.send("closeModal");
        }
        if (opts.message) {
          controller.set("message", "");
        }
      })
      .catch((error) => {
        if (!controller.isDestroying && !controller.isDestroyed) {
          controller.send("closeModal");
        }
        popupAjaxError(error);
      });
  }
}
