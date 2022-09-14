import { popupAjaxError } from "discourse/lib/ajax-error";

export default class Flag {
  flaggingTopic() {
    return false;
  }

  isEditable() {
    return true;
  }

  createFlag(controller, opts) {
    // an instance of ActionSummary
    let postAction = this.postActionFor(controller);

    let params = controller.get("selected.is_custom_flag")
      ? { message: this.message }
      : {};

    if (opts) {
      params = Object.assign(params, opts);
    }

    controller.appEvents.trigger(
      this.flagCreatedEvent,
      controller.model,
      postAction,
      params
    );

    controller.send("hideModal");

    postAction
      .act(controller.model, params)
      .then(() => {
        if (controller.isDestroying || controller.isDestroyed) {
          return;
        }

        if (!params.skipClose) {
          controller.send("closeModal");
        }
        if (params.message) {
          controller.set("message", "");
        }
        controller.appEvents.trigger("post-stream:refresh", {
          id: controller.get("model.id"),
        });
      })
      .catch((error) => {
        if (!controller.isDestroying && !controller.isDestroyed) {
          controller.send("closeModal");
        }
        popupAjaxError(error);
      });
  }
}
