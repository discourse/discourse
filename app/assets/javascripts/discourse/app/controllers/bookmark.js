import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { action } from "@ember/object";
import { Promise } from "rsvp";
import showModal from "discourse/lib/show-modal";

export function openBookmarkModal(
  bookmark,
  callbacks = {
    onCloseWithoutSaving: null,
    onAfterSave: null,
    onAfterDelete: null,
  }
) {
  return new Promise((resolve) => {
    const modalTitle = () => {
      if (bookmark.for_topic) {
        return bookmark.id
          ? "post.bookmarks.edit_for_topic"
          : "post.bookmarks.create_for_topic";
      }
      return bookmark.id ? "post.bookmarks.edit" : "post.bookmarks.create";
    };
    let modalController = showModal("bookmark", {
      model: {
        postId: bookmark.post_id,
        topicId: bookmark.topic_id,
        id: bookmark.id,
        reminderAt: bookmark.reminder_at,
        lastReminderAt: bookmark.last_reminder_at,
        autoDeletePreference: bookmark.auto_delete_preference,
        name: bookmark.name,
        forTopic: bookmark.for_topic,
      },
      title: modalTitle(),
      modalClass: "bookmark-with-reminder",
    });
    modalController.setProperties({
      onCloseWithoutSaving: () => {
        if (callbacks.onCloseWithoutSaving) {
          callbacks.onCloseWithoutSaving();
        }
        resolve();
      },
      afterSave: (savedData) => {
        let resolveData;
        if (callbacks.onAfterSave) {
          resolveData = callbacks.onAfterSave(savedData);
        }
        resolve(resolveData);
      },
      afterDelete: (topicBookmarked, bookmarkId) => {
        if (callbacks.onAfterDelete) {
          callbacks.onAfterDelete(topicBookmarked, bookmarkId);
        }
        resolve();
      },
    });
  });
}

export default Controller.extend(ModalFunctionality, {
  onShow() {
    this.setProperties({
      model: this.model || {},
      allowSave: true,
    });
  },

  @action
  registerOnCloseHandler(handlerFn) {
    this.set("onCloseHandler", handlerFn);
  },

  /**
   * We always want to save the bookmark unless the user specifically
   * clicks the save or cancel button to mimic browser behaviour.
   */
  onClose(opts = {}) {
    if (this.onCloseHandler) {
      this.onCloseHandler(opts);
    }
  },
});
