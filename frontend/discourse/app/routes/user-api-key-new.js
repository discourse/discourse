import { ajax } from "discourse/lib/ajax";
import PreloadStore from "discourse/lib/preload-store";
import { USER_API_KEY_AUTHORIZATION_STATES } from "discourse/lib/user-api-key-device-auth";
import DiscourseRoute from "discourse/routes/discourse";

export default class UserApiKeyNewRoute extends DiscourseRoute {
  queryParams = {
    nonce: { refreshModel: true },
    scopes: { refreshModel: true },
    client_id: { refreshModel: true },
    application_name: { refreshModel: true },
    public_key: { refreshModel: true },
    auth_redirect: { refreshModel: true },
    push_url: { refreshModel: true },
    padding: { refreshModel: true },
    expires_in_seconds: { refreshModel: true },
  };

  model() {
    if (PreloadStore.data.has("user_api_key_authorization")) {
      return PreloadStore.getAndRemove("user_api_key_authorization");
    }

    return ajax(`/user-api-key/new.json${window.location.search}`).catch(
      () => ({
        state: USER_API_KEY_AUTHORIZATION_STATES.GENERIC_ERROR,
      })
    );
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    controller.reset(model);
  }
}
