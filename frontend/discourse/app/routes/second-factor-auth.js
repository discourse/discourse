import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import PreloadStore from "discourse/lib/preload-store";
import DiscourseRoute from "discourse/routes/discourse";

export default class SecondFactorAuth extends DiscourseRoute {
  queryParams = {
    nonce: { refreshModel: true },
  };

  model(params) {
    if (PreloadStore.data.has("2fa_challenge_data")) {
      return PreloadStore.getAndRemove("2fa_challenge_data");
    } else {
      return ajax("/session/2fa.json", {
        type: "GET",
        data: { nonce: params.nonce },
      }).catch((errorResponse) => {
        const error = extractError(errorResponse);
        if (error) {
          return { error };
        } else {
          throw errorResponse;
        }
      });
    }
  }

  setupController(controller, model) {
    super.setupController(...arguments);
    controller.resetState();

    if (model.error) {
      controller.displayError(model.error);
      controller.set("loadError", true);
    }
  }
}
