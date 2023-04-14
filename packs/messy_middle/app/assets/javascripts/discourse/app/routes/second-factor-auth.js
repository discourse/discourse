import DiscourseRoute from "discourse/routes/discourse";
import PreloadStore from "discourse/lib/preload-store";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";

export default DiscourseRoute.extend({
  queryParams: {
    nonce: { refreshModel: true },
  },

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
  },

  activate() {
    this.controllerFor("application").setProperties({
      sidebarDisabledRouteOverride: true,
    });
  },

  deactivate() {
    this.controllerFor("application").setProperties({
      sidebarDisabledRouteOverride: false,
    });
  },

  setupController(controller, model) {
    this._super(...arguments);
    controller.resetState();

    if (model.error) {
      controller.displayError(model.error);
      controller.set("loadError", true);
    }
  },
});
