import { apiInitializer } from "discourse/lib/api";
import cookie from "discourse/lib/cookie";

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
      const showOriginal = currentUser
        ? currentUser.user_option?.show_original_content
        : cookie("content-localization-show-original");

      if (!showOriginal) {
        const postStream = topicController.get("model.postStream");
        postStream.triggerChangedPost(data.id, data.updated_at);
      }
    }
  );
});
