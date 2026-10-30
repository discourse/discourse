import Service, { service } from "@ember/service";
import DsaModerationAction from "discourse/components/modal/dsa-moderation-action";

export default class ReviewableDsa extends Service {
  @service modal;

  optionsFor({ action, options }) {
    if (
      action.dsa_classification_required &&
      options?.community_rules?.length
    ) {
      return options;
    }
  }

  handlesConfirmation({ action, options, modalClass }) {
    return (
      this.optionsFor({ action, options }) &&
      (!modalClass || action.server_action === "revise_and_reject_post")
    );
  }

  async perform({
    action,
    reviewable,
    options,
    modalClass,
    claim,
    dispatch,
    performAction,
  }) {
    const classify = async (perform, data = {}) => {
      if (await claim()) {
        return this.modal.show(DsaModerationAction, {
          model: {
            action,
            options,
            perform: (classification) =>
              perform({ ...data, ...classification }),
          },
        });
      }
    };

    if (action.client_action === "edit") {
      return classify((classification) =>
        dispatch((data) => performAction({ ...data, ...classification }))
      );
    }

    if (modalClass) {
      if (await claim()) {
        return this.modal.show(modalClass, {
          model: {
            action,
            reviewable,
            classificationOptions: options,
            performConfirmed: (_action, data) => performAction(data),
          },
        });
      }
      return;
    }

    let classificationPromise;
    await dispatch((data) => {
      if (data?.dsa_classification) {
        return performAction(data);
      }
      classificationPromise = classify(performAction, data);
      return classificationPromise;
    });
    return classificationPromise;
  }
}
