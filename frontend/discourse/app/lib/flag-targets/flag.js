import { popupAjaxError } from "discourse/lib/ajax-error";

export default class Flag {
  targetsTopic() {
    return false;
  }

  editable() {
    return true;
  }

  create(flagModal, opts) {
    // an instance of ActionSummary
    const postAction = this.postActionFor(flagModal);
    flagModal.appEvents.trigger(
      this.flagCreatedEvent(),
      flagModal.args.model.flagModel,
      postAction,
      opts
    );

    flagModal.args.closeModal();
    postAction
      .act(flagModal.args.model.flagModel, opts)
      .catch((error) => popupAjaxError(error));
  }
}
