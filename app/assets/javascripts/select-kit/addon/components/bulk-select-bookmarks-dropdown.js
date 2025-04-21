import { action } from "@ember/object";
import { service } from "@ember/service";
import { classNames } from "@ember-decorators/component";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Bookmark from "discourse/models/bookmark";
import { i18n } from "discourse-i18n";
import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import { selectKitOptions } from "./select-kit";

const _customButtons = [];
const _customActions = {};

export function addBulkDropdownAction(name, customAction) {
  _customActions[name] = customAction;
}

@classNames("bulk-select-bookmarks-dropdown")
@selectKitOptions({
  showCaret: true,
  showFullTitle: true,
  none: "select_kit.components.bulk_select_bookmarks_dropdown.title",
})
export default class BulkSelectBookmarksDropdown extends DropdownSelectBoxComponent {
  @service router;
  @service toasts;
  @service dialog;

  headerIcon = null;

  get content() {
    let options = [];
    options = options.concat([
      {
        id: "clear-reminders",
        icon: "tag",
        name: i18n("bookmark_bulk_actions.clear_reminders.name"),
      },
      {
        id: "delete-bookmarks",
        icon: "trash-can",
        name: i18n("bookmark_bulk_actions.delete_bookmarks.name"),
      },
    ]);

    return [...options, ..._customButtons];
  }

  getSelectedBookmarks() {
    return this.bulkSelectHelper.selected;
  }

  @action
  onSelect(id) {
    switch (id) {
      case "clear-reminders":
        this.dialog.yesNoConfirm({
          message: i18n(
            `js.bookmark_bulk_actions.clear_reminders.description`,
            {
              count: this.getSelectedBookmarks().length,
            }
          ),
          didConfirm: () => {
            Bookmark.bulkOperation(this.getSelectedBookmarks(), {
              type: "clear_reminder",
            })
              .then(() => {
                this.router.refresh();
                this.bulkSelectHelper.clear();
                this.toasts.success({
                  duration: 3000,
                  data: { message: i18n("bookmarks.bulk.reminders_cleared") },
                });
              })
              .catch(popupAjaxError);
          },
        });
        break;
      case "delete-bookmarks":
        this.dialog.deleteConfirm({
          message: i18n(
            `js.bookmark_bulk_actions.delete_bookmarks.description`,
            {
              count: this.getSelectedBookmarks().length,
            }
          ),
          didConfirm: () => {
            Bookmark.bulkOperation(this.getSelectedBookmarks(), {
              type: "delete",
            })
              .then(() => {
                this.router.refresh();
                this.bulkSelectHelper.clear();
                this.toasts.success({
                  duration: 3000,
                  data: { message: i18n("bookmarks.bulk.delete_completed") },
                });
              })
              .catch(popupAjaxError);
          },
        });
    }
  }
}
