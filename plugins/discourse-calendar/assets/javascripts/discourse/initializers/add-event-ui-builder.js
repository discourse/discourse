import { withPluginApi } from "discourse/lib/plugin-api";
import DiscoursePostEventEvent from "discourse/plugins/discourse-calendar/discourse/models/discourse-post-event-event";
import PostEventBuilder from "../components/modal/post-event-builder";

function initializeEventBuilder(api) {
  const currentUser = api.getCurrentUser();
  const modal = api.container.lookup("service:modal");

  api.addComposerToolbarPopupMenuOption({
    action: (toolbarEvent) => {
      const event = DiscoursePostEventEvent.create({
        status: "public",
        starts_at: moment(),
        timezone: moment.tz.guess(),
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
      withPluginApi("0.8.7", initializeEventBuilder);
    }
  },
};
