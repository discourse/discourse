import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import PreloadStore from "discourse/lib/preload-store";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

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

    if (model.error || controller.shownSecondFactorMethod === null) {
      controller.displayError(
        model.error || i18n("second_factor_auth.no_available_method")
      );
      controller.set("loadError", true);
    } else {
      controller.maybeAutoTriggerPasskey();
    }
  }
}
