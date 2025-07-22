import { apiInitializer } from "discourse/lib/api";
import cookie from "discourse/lib/cookie";

export default apiInitializer((api) => {
  const settings = api.container.lookup("service:site-settings");

  if (!settings.discourse_ai_enabled || !settings.ai_translation_enabled) {
    return;
  }

  api.registerCustomPostMessageCallback(
    "localized",
    (topicController, data) => {
      if (!cookie("content-localization-show-original")) {
        const postStream = topicController.get("model.postStream");
        postStream.triggerChangedPost(data.id, data.updated_at).then(() => {
          topicController.appEvents.trigger("post-stream:refresh", {
            id: data.id,
          });
        });
      }
    }
  );
});
