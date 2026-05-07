import { withPluginApi } from "discourse/lib/plugin-api";
import DiscoursePostEventEvent from "discourse/plugins/discourse-calendar/discourse/models/discourse-post-event-event";
import PostEventBuilder from "../components/modal/post-event-builder";

function initializeEventBuilder(api) {
  const currentUser = api.getCurrentUser();
  const modal = api.container.lookup("service:modal");
  const siteSettings = api.container.lookup("service:site-settings");

  api.addComposerToolbarPopupMenuOption({
    action: (toolbarEvent) => {
      const userTz = currentUser?.user_option?.timezone;
      const timezone = userTz || moment.tz.guess();
      const start = moment.tz(moment(), timezone);
      const end = start.clone().add(1, "hour");

      if (siteSettings.rich_editor && currentUser.useRichEditor) {
        const params = `start="${start.format("YYYY-MM-DD HH:mm")}" end="${end.format("YYYY-MM-DD HH:mm")}" status="public" timezone="${timezone}"`;
        toolbarEvent.addText(`[event ${params}]\n[/event]`);
        return;
      }

      const event = DiscoursePostEventEvent.create({
        status: "public",
        starts_at: start,
        ends_at: end,
        timezone,
      });

      modal.show(PostEventBuilder, {
        model: { event, toolbarEvent },
      });
    },
    group: "insertions",
    icon: "calendar-day",
    label: "discourse_post_event.builder_modal.attach",
    condition: (composer) => {
      if (!currentUser || !currentUser.can_create_discourse_post_event) {
        return false;
      }

      const composerModel = composer.model;
      return (
        composerModel &&
        !composerModel.replyingToTopic &&
        (composerModel.topicFirstPost ||
          composerModel.creatingPrivateMessage ||
          (composerModel.editingPost &&
            composerModel.post &&
            composerModel.post.post_number === 1))
      );
    },
  });
}

export default {
  name: "add-post-event-builder",
  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    if (siteSettings.discourse_post_event_enabled) {
      withPluginApi(initializeEventBuilder);
    }
  },
};
