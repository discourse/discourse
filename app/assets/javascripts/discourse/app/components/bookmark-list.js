import Component from "@ember/component";
import I18n from "I18n";
import { schedule } from "@ember/runloop";
import { action } from "@ember/object";
import showModal from "discourse/lib/show-modal";
import {
  shouldOpenInNewTab,
  openLinkInNewTab
} from "discourse/lib/click-track";

export default Component.extend({
  classNames: ["bookmark-list-wrapper"],

  didInsertElement() {
    this._super(...arguments);

    schedule("afterRender", () => {
      this.element.addEventListener("click", this._wrapperClickHandler);
    });
  },

  willDestroyElement() {
    this._super(...arguments);

    this.element.removeEventListener("click", this._wrapperClickHandler);
  },

  @action
  loadMoreBookmarks() {
    this.loadMore();
  },

  @action
  removeBookmark(bookmark) {
    const deleteBookmark = () => {
      return bookmark
        .destroy()
        .then(() => this._removeBookmarkFromList(bookmark));
    };
    if (!bookmark.reminder_at) {
      return deleteBookmark();
    }
    bootbox.confirm(I18n.t("bookmarks.confirm_delete"), result => {
      if (result) {
        return deleteBookmark();
      }
    });
  },

  @action
  editBookmark(bookmark) {
    let controller = showModal("bookmark", {
      model: {
        postId: bookmark.post_id,
        id: bookmark.id,
        reminderAt: bookmark.reminder_at,
        name: bookmark.name
      },
      title: "post.bookmarks.edit",
      modalClass: "bookmark-with-reminder"
    });
    controller.setProperties({
      afterSave: () => this.reload()
    });
  },

  _removeBookmarkFromList(bookmark) {
    this.content.removeObject(bookmark);
  },

  _wrapperClickHandler(e) {
    if (e.target && e.target.tagName === "A") {
      let link = e.target;
      if (shouldOpenInNewTab(link.href)) {
        openLinkInNewTab(link);
      }
    }
  }
});
