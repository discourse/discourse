import {
  openLinkInNewTab,
  shouldOpenInNewTab,
} from "discourse/lib/click-track";
import Component from "@ember/component";
import I18n from "I18n";
import { Promise } from "rsvp";
import { action } from "@ember/object";
import bootbox from "bootbox";
import { openBookmarkModal } from "discourse/controllers/bookmark";

export default Component.extend({
  classNames: ["bookmark-list-wrapper"],

  @action
  removeBookmark(bookmark) {
    return new Promise((resolve, reject) => {
      const deleteBookmark = () => {
        bookmark
          .destroy()
          .then(() => {
            this.appEvents.trigger(
              "bookmarks:changed",
              null,
              bookmark.attachedTo()
            );
            this._removeBookmarkFromList(bookmark);
            resolve(true);
          })
          .catch((error) => {
            reject(error);
          });
      };
      if (!bookmark.reminder_at) {
        return deleteBookmark();
      }
      bootbox.confirm(I18n.t("bookmarks.confirm_delete"), (result) => {
        if (result) {
          deleteBookmark();
        } else {
          resolve(false);
        }
      });
    });
  },

  @action
  screenExcerptForExternalLink(event) {
    if (event.target && event.target.tagName === "A") {
      let link = event.target;
      if (shouldOpenInNewTab(link.href)) {
        openLinkInNewTab(link);
      }
    }
  },

  @action
  editBookmark(bookmark) {
    openBookmarkModal(bookmark, {
      onAfterSave: (savedData) => {
        this.appEvents.trigger(
          "bookmarks:changed",
          savedData,
          bookmark.attachedTo()
        );
        this.reload();
      },
      onAfterDelete: () => {
        this.reload();
      },
    });
  },

  @action
  togglePinBookmark(bookmark) {
    bookmark.togglePin().then(this.reload);
  },

  _removeBookmarkFromList(bookmark) {
    this.content.removeObject(bookmark);
  },
});
