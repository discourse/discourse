import Component from "@ember/component";
import { Promise } from "rsvp";
import I18n from "I18n";
import { action } from "@ember/object";
import showModal from "discourse/lib/show-modal";
import {
  shouldOpenInNewTab,
  openLinkInNewTab,
} from "discourse/lib/click-track";
import bootbox from "bootbox";

export default Component.extend({
  classNames: ["bookmark-list-wrapper"],

  @action
  removeBookmark(bookmark) {
    return new Promise((resolve, reject) => {
      const deleteBookmark = () => {
        bookmark
          .destroy()
          .then(() => {
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
    let controller = showModal("bookmark", {
      model: {
        postId: bookmark.post_id,
        id: bookmark.id,
        reminderAt: bookmark.reminder_at,
        name: bookmark.name,
      },
      title: "post.bookmarks.edit",
      modalClass: "bookmark-with-reminder",
    });
    controller.set("afterSave", () => this.reload());
  },

  _removeBookmarkFromList(bookmark) {
    this.content.removeObject(bookmark);
  },
});
