import { popupAjaxError } from "discourse/lib/ajax-error";

export default class Flag {
  targetsTopic() {
    return false;
  }

  editable() {
    return true;
  }

  create(controller, opts) {
    // an instance of ActionSummary
    let postAction = this.postActionFor(controller);

    controller.appEvents.trigger(
      this.flagCreatedEvent,
      controller.model,
      postAction,
      opts
    );

    controller.send("hideModal");

    postAction
      .act(controller.model, opts)
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
