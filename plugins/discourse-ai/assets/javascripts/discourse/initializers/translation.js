import { apiInitializer } from "discourse/lib/api";
import cookie from "discourse/lib/cookie";
import { EDIT } from "discourse/models/composer";

export default apiInitializer((api) => {
  const settings = api.container.lookup("service:site-settings");

  if (!settings.discourse_ai_enabled || !settings.ai_translation_enabled) {
    return;
  }

  // When AI translation is enabled, hide the manual language selector for new posts (auto-detected)
  // but keep it visible when editing so users can correct wrong detections
  api.registerValueTransformer(
    "post-language-selector-should-show",
    ({ value, context }) => {
      if (context.action === EDIT) {
        return value;
      }
      return false;
    }
  );

  api.registerCustomPostMessageCallback(
    "localized",
    (topicController, data) => {
      const currentUser = api.getCurrentUser();
      const showOriginal =
        currentUser?.user_option?.show_original_content ||
        cookie("content-localization-show-original");

      if (!showOriginal) {
        const postStream = topicController.get("model.postStream");
        postStream.triggerChangedPost(data.id, data.updated_at);
      }
    }
  );
});
