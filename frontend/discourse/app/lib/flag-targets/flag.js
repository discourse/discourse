import { popupAjaxError } from "discourse/lib/ajax-error";

export default class Flag {
  targetsTopic() {
    return false;
  }

  editable() {
    return true;
  }

  /**
   * @returns {Promise<boolean>} resolves `false` when the flag was not created
   */
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
    return postAction
      .act(flagModal.args.model.flagModel, opts)
      .then((result) => !!result?.acted)
      .catch((error) => {
        popupAjaxError(error);
        return false;
      });
  }
}
