import { ajax } from "discourse/lib/ajax";
import PreloadStore from "discourse/lib/preload-store";
import DiscourseRoute from "discourse/routes/discourse";

export default class UserApiKeyActivateRoute extends DiscourseRoute {
  queryParams = {
    request: { refreshModel: true },
  };

  model() {
    if (PreloadStore.data.has("user_api_key_device_activation")) {
      return PreloadStore.getAndRemove("user_api_key_device_activation");
    }

    return ajax(`/user-api-key/activate.json${window.location.search}`);
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    controller.reset(model);
  }
}
