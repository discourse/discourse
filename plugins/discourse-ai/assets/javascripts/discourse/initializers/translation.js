import { apiInitializer } from "discourse/lib/api";
import { automaticallyTranslate } from "discourse/lib/content-localization";

export default apiInitializer((api) => {
  const settings = api.container.lookup("service:site-settings");

  if (!settings.discourse_ai_enabled || !settings.ai_translation_enabled) {
    return;
  }

  // When AI translation is enabled, deprioritize the manual language selector since language is auto-detected
  api.registerValueTransformer("post-language-selector-priority", () => "last");

  api.registerCustomPostMessageCallback(
    "localized",
    (topicController, data) => {
      const currentUser = api.getCurrentUser();

      if (automaticallyTranslate(currentUser)) {
        const postStream = topicController.get("model.postStream");
        postStream.triggerChangedPost(data.id, data.updated_at);
      }
    }
  );
});
