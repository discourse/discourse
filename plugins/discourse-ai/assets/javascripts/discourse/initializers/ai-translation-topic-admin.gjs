import { ajax } from "discourse/lib/ajax";
import { apiInitializer } from "discourse/lib/api";
import { i18n } from "discourse-i18n";

/**
 * Initializer that adds a topic admin menu button for scheduling translations
 * of untranslated posts in a topic.
 *
 * @module ai-translation-topic-admin
 */
export default apiInitializer((api) => {
  const settings = api.container.lookup("service:site-settings");

  if (!settings.discourse_ai_enabled || !settings.ai_translation_enabled) {
    return;
  }

  api.addTopicAdminMenuButton((topic) => {
    const currentUser = api.getCurrentUser();

    if (!currentUser) {
      return;
    }

    const allowedGroups = settings.content_localization_allowed_groups
      .split("|")
      .map((id) => parseInt(id, 10));

    const userGroupIds = currentUser.groups.map((g) => g.id);
    const hasPermission = allowedGroups.some((groupId) =>
      userGroupIds.includes(groupId)
    );

    if (!hasPermission) {
      return;
    }

    return {
      action: async () => {
        const toasts = api.container.lookup("service:toasts");

        try {
          const result = await ajax(
            `/discourse-ai/translate/topics/${topic.id}`,
            {
              type: "POST",
            }
          );

          toasts.success({
            duration: 5000,
            data: {
              message: i18n("discourse_ai.translation.schedule_topic_success", {
                count: result.scheduled_posts,
              }),
            },
          });
        } catch (error) {
          const errorMessage =
            error.jqXHR?.responseJSON?.errors?.[0] ||
            i18n("discourse_ai.translation.schedule_topic_error");

          toasts.error({
            duration: 5000,
            data: {
              message: errorMessage,
            },
          });
        }
      },
      icon: "language",
      className: "schedule-topic-translations-button",
      label: "discourse_ai.ai_features.translation.schedule_untranslated",
    };
  });
});
