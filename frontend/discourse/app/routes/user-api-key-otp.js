import { ajax } from "discourse/lib/ajax";
import PreloadStore from "discourse/lib/preload-store";
import DiscourseRoute from "discourse/routes/discourse";

export default class UserApiKeyOtpRoute extends DiscourseRoute {
  queryParams = {
    application_name: { refreshModel: true },
    public_key: { refreshModel: true },
    auth_redirect: { refreshModel: true },
    padding: { refreshModel: true },
  };

  model() {
    if (PreloadStore.data.has("user_api_key_otp")) {
      return PreloadStore.getAndRemove("user_api_key_otp");
    }

    return ajax(`/user-api-key/otp.json${window.location.search}`);
  }
}
