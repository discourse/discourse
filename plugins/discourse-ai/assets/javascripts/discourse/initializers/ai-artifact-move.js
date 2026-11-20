import { ajax } from "discourse/lib/ajax";
import { apiInitializer } from "discourse/lib/api";
import { i18n } from "discourse-i18n";

export default apiInitializer((api) => {
  const siteSettings = api.container.lookup("service:site-settings");
  if (
    !siteSettings.discourse_ai_enabled ||
    !["lax", "hybrid", "strict"].includes(siteSettings.ai_artifact_security)
  ) {
    return;
  }

  const dialog = api.container.lookup("service:dialog");
  api.registerBehaviorTransformer(
    "move-to-topic",
    async ({ context, next }) => {
      const { count } = await ajax(
        "/discourse-ai/ai-bot/artifacts/move-warning.json",
        {
          type: "POST",
          data: {
            topic_id: context.topic.id,
            all_posts: Boolean(context.allPosts),
            post_ids: context.options.post_ids,
            destination_topic_id: context.options.destination_topic_id,
            category_id: context.options.category_id,
            archetype: context.options.archetype,
            freeze_original: context.options.freeze_original,
          },
        }
      );
      if (
        count > 0 &&
        !(await dialog.confirm({
          title: i18n("discourse_ai.ai_artifact.move_warning_title"),
          message: i18n("discourse_ai.ai_artifact.move_warning_message", {
            count,
          }),
          confirmButtonClass: "btn-danger",
          confirmButtonLabel: "discourse_ai.ai_artifact.move_warning_confirm",
        }))
      ) {
        return;
      }
      return next();
    }
  );
});
