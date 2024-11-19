import { action } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import discourseComputed from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";
import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import {
  pluginApiIdentifiers,
  selectKitOptions,
} from "select-kit/components/select-kit";

const ACTION_REMOVE = "remove";
const ACTION_EDIT = "edit";
const ACTION_CLEAR_REMINDER = "clear_reminder";
const ACTION_PIN = "pin";

@classNames("bookmark-actions-dropdown")
@selectKitOptions({
  icon: null,
  translatedNone: "...",
  showFullTitle: true,
})
@pluginApiIdentifiers("bookmark-actions-dropdown")
export default class BookmarkActionsDropdown extends DropdownSelectBoxComponent {
  @discourseComputed("bookmark")
  content(bookmark) {
    const actions = [];

    actions.push({
      id: ACTION_REMOVE,
      icon: "trash-can",
      name: i18n("post.bookmarks.actions.delete_bookmark.name"),
      description: i18n("post.bookmarks.actions.delete_bookmark.description"),
    });

    actions.push({
      id: ACTION_EDIT,
      icon: "pencil",
      name: i18n("post.bookmarks.actions.edit_bookmark.name"),
      description: i18n("post.bookmarks.actions.edit_bookmark.description"),
    });

    if (bookmark.reminder_at) {
      actions.push({
        id: ACTION_CLEAR_REMINDER,
        icon: "clock-rotate-left",
        name: i18n("post.bookmarks.actions.clear_bookmark_reminder.name"),
        description: i18n(
          "post.bookmarks.actions.clear_bookmark_reminder.description"
        ),
      });
    }

    actions.push({
      id: ACTION_PIN,
      icon: "thumbtack",
      name: i18n(
        `post.bookmarks.actions.${bookmark.pinAction()}_bookmark.name`
      ),
      description: i18n(
        `post.bookmarks.actions.${bookmark.pinAction()}_bookmark.description`
      ),
    });

    return actions;
  }

  @action
  onChange(selectedAction) {
    if (selectedAction === ACTION_REMOVE) {
      this.removeBookmark(this.bookmark);
    } else if (selectedAction === ACTION_EDIT) {
      this.editBookmark(this.bookmark);
    } else if (selectedAction === ACTION_CLEAR_REMINDER) {
      this.clearBookmarkReminder(this.bookmark);
    } else if (selectedAction === ACTION_PIN) {
      this.togglePinBookmark(this.bookmark);
    }
  }
}
