import PreloadStore from "discourse/lib/preload-store";
import DiscourseRoute from "discourse/routes/discourse";

export default class UserApiKeyResultRoute extends DiscourseRoute {
  model() {
    if (PreloadStore.data.has("user_api_key_result")) {
      return PreloadStore.getAndRemove("user_api_key_result");
    }

    return {};
  }
}
