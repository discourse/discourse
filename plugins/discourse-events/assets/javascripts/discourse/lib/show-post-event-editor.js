import { i18n } from "discourse-i18n";
import PostEventBuilder from "../components/modal/post-event-builder";
import { buildParams, removeEvent, replaceRaw } from "./raw-event-helper";
import { savePostRaw } from "./save-post-raw";

// Opens the event builder against a published event, writing changes back to
// the post's raw.
export function showPostEventEditor({ modal, store, event }) {
  return modal.show(PostEventBuilder, {
    model: {
      event,
      onDelete: async (deletedEvent) => {
        const post = await store.find("post", deletedEvent.id);

        return await savePostRaw(
          post,
          removeEvent(post.raw),
          i18n("discourse_post_event.destroy_event")
        );
      },
      onUpdate: async (startsAt, endsAt, updatedEvent, siteSettings) => {
        const post = await store.find("post", updatedEvent.id);
        const newRaw = replaceRaw(
          buildParams(startsAt, endsAt, updatedEvent, siteSettings),
          post.raw
        );

        if (newRaw) {
          return await savePostRaw(
            post,
            newRaw,
            i18n("discourse_post_event.edit_reason")
          );
        }
      },
    },
  });
}
