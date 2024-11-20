import Component from "@ember/component";
import { action } from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import { service } from "@ember/service";
import { classNames } from "@ember-decorators/component";
import { Promise } from "rsvp";
import BookmarkModal from "discourse/components/modal/bookmark";
import { ajax } from "discourse/lib/ajax";
import { BookmarkFormData } from "discourse/lib/bookmark-form-data";
import {
  openLinkInNewTab,
  shouldOpenInNewTab,
} from "discourse/lib/click-track";
import { i18n } from "discourse-i18n";

@classNames("bookmark-list-wrapper")
export default class BookmarkList extends Component {
  @service dialog;
  @service modal;

  get canDoBulkActions() {
    return this.bulkSelectHelper?.selected.length;
  }

  get selected() {
    return this.bulkSelectHelper?.selected;
  }

  get selectedCount() {
    return this.selected?.length || 0;
  }

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
      this.dialog.deleteConfirm({
        message: i18n("bookmarks.confirm_delete"),
        didConfirm: () => deleteBookmark(),
        didCancel: () => resolve(false),
      });
    });
  }

  @action
  screenExcerptForExternalLink(event) {
    if (event?.target?.tagName === "A") {
      if (shouldOpenInNewTab(event.target.href)) {
        openLinkInNewTab(event, event.target);
      }
    }
  }

  @action
  editBookmark(bookmark) {
    this.modal.show(BookmarkModal, {
      model: {
        bookmark: new BookmarkFormData(bookmark),
        afterSave: (savedData) => {
          this.appEvents.trigger(
            "bookmarks:changed",
            savedData,
            bookmark.attachedTo()
          );
          this.reload();
        },
        afterDelete: () => {
          this.reload();
        },
      },
    });
  }

  @action
  clearBookmarkReminder(bookmark) {
    return ajax(`/bookmarks/${bookmark.id}`, {
      type: "PUT",
      data: { reminder_at: null },
    }).then(() => {
      bookmark.set("reminder_at", null);
    });
  }

  @action
  togglePinBookmark(bookmark) {
    bookmark.togglePin().then(this.reload);
  }

  @action
  toggleBulkSelect() {
    this.bulkSelectHelper?.toggleBulkSelect();
    this.rerender();
  }

  @action
  selectAll() {
    this.bulkSelectHelper.autoAddBookmarksToBulkSelect = true;
    document
      .querySelectorAll("input.bulk-select:not(:checked)")
      .forEach((el) => el.click());
  }

  @action
  clearAll() {
    this.bulkSelectHelper.autoAddBookmarksToBulkSelect = false;
    document
      .querySelectorAll("input.bulk-select:checked")
      .forEach((el) => el.click());
  }

  @dependentKeyCompat // for the classNameBindings
  get bulkSelectEnabled() {
    return this.bulkSelectHelper?.bulkSelectEnabled;
  }

  _removeBookmarkFromList(bookmark) {
    this.content.removeObject(bookmark);
  }

  _toggleSelection(target, bookmark, isSelectingRange) {
    const selected = this.selected;

    if (target.checked) {
      selected.addObject(bookmark);

      if (isSelectingRange) {
        const bulkSelects = Array.from(
            document.querySelectorAll("input.bulk-select")
          ),
          from = bulkSelects.indexOf(target),
          to = bulkSelects.findIndex((el) => el.id === this.lastChecked.id),
          start = Math.min(from, to),
          end = Math.max(from, to);

        bulkSelects
          .slice(start, end)
          .filter((el) => el.checked !== true)
          .forEach((checkbox) => {
            checkbox.click();
          });
      }
      this.set("lastChecked", target);
    } else {
      selected.removeObject(bookmark);
      this.set("lastChecked", null);
    }
  }

  click(e) {
    const onClick = (sel, callback) => {
      let target = e.target.closest(sel);

      if (target) {
        callback(target);
      }
    };

    onClick("input.bulk-select", () => {
      const target = e.target;
      const bookmarkId = target.dataset.id;
      const bookmark = this.content.find(
        (item) => item.id.toString() === bookmarkId
      );
      this._toggleSelection(target, bookmark, this.lastChecked && e.shiftKey);
    });
  }
}
