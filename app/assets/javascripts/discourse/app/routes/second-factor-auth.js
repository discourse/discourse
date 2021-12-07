import DiscourseRoute from "discourse/routes/discourse";
import PreloadStore from "discourse/lib/preload-store";
import { ajax } from "discourse/lib/ajax";

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
      });
    }
  },

  setupController(controller) {
    this._super(...arguments);
    controller.resetState();
  },
});
