import Controller from "@ember/controller";
import I18n from "I18n";
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
    const model = {
      id: bookmark.id,
      reminderAt: bookmark.reminder_at,
      autoDeletePreference: bookmark.auto_delete_preference,
      name: bookmark.name,
    };

    model.bookmarkableId = bookmark.bookmarkable_id;
    model.bookmarkableType = bookmark.bookmarkable_type;

    let modalController = showModal("bookmark", {
      model,
      titleTranslated: I18n.t(
        bookmark.id ? "bookmarks.edit" : "bookmarks.create"
      ),
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
