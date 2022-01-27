import Component from "@ember/component";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import bootbox from "bootbox";
import discourseDebounce from "discourse-common/lib/debounce";
import { openBookmarkModal } from "discourse/controllers/bookmark";
import {
  openLinkInNewTab,
  shouldOpenInNewTab,
} from "discourse/lib/click-track";
import Scrolling from "discourse/mixins/scrolling";
import I18n from "I18n";
import { Promise } from "rsvp";

export default Component.extend(Scrolling, {
  classNames: ["bookmark-list-wrapper"],

  didInsertElement() {
    this._super(...arguments);
    this.bindScrolling();
    this.scrollToLastPosition();
  },

  willDestroyElement() {
    this._super(...arguments);
    this.unbindScrolling();
  },

  scrollToLastPosition() {
    let scrollTo = this.session.bookmarkListScrollPosition;
    if (scrollTo && scrollTo >= 0) {
      schedule("afterRender", () => {
        discourseDebounce(
          this,
          function () {
            if (this.element && !this.isDestroying && !this.isDestroyed) {
              window.scrollTo(0, scrollTo + 1);
            }
          },
          0
        );
      });
    }
  },

  scrolled() {
    this._super(...arguments);
    this.session.set("bookmarkListScrollPosition", window.scrollY);
  },

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
