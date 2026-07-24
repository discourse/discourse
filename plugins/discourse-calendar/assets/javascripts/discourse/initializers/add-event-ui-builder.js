import { withPluginApi } from "discourse/lib/plugin-api";
import DiscoursePostEventEvent from "discourse/plugins/discourse-calendar/discourse/models/discourse-post-event-event";
import PostEventBuilder from "../components/modal/post-event-builder";
import { defaultReminderFor, reminderToBBCode } from "../lib/raw-event-helper";

function initializeEventBuilder(api) {
  const currentUser = api.getCurrentUser();
  const modal = api.container.lookup("service:modal");
  const composer = api.container.lookup("service:composer");

  api.addComposerToolbarPopupMenuOption({
    action: (toolbarEvent) => {
      const userTz = currentUser?.user_option?.timezone;
      const timezone = userTz || moment.tz.guess();
      const start = moment
        .tz(moment(), timezone)
        .startOf("hour")
        .add(1, "hour");
      const end = start.clone().add(1, "hour");
      const reminder = defaultReminderFor({
        startsAt: start,
        endsAt: end,
        allDay: false,
      });

      // Insert inline whenever the user will see the editor immediately —
      // either the ProseMirror node view (rich-text) or the markdown preview
      // pane. Fall back to the modal when there's no visible surface (preview
      // toggled off, or mobile where it's behind a tap).
      const richTextMode = currentUser.useRichEditor;
      if (richTextMode || composer.isPreviewVisible) {
        const params = `start="${start.format("YYYY-MM-DD HH:mm")}" end="${end.format("YYYY-MM-DD HH:mm")}" status="public" timezone="${timezone}" reminders="${reminderToBBCode(reminder)}"`;
        toolbarEvent.addText(`[event ${params}]\n[/event]`);
        return;
      }

      const event = DiscoursePostEventEvent.create({
        status: "public",
        starts_at: start,
        ends_at: end,
        timezone,
        reminders: [reminder],
      });

      modal.show(PostEventBuilder, {
        model: { event, toolbarEvent },
      });
    },
    group: "insertions",
    icon: "calendar-day",
    label: "discourse_post_event.builder_modal.attach",
    condition: (composerArg) => {
      if (!currentUser || !currentUser.can_create_discourse_post_event) {
        return false;
      }

      const composerModel = composerArg.model;
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
