import { action } from "@ember/object";
import discourseComputed from "discourse-common/utils/decorators";
import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import I18n from "I18n";

const ACTION_REMOVE = "remove";
const ACTION_EDIT = "edit";
const ACTION_CLEAR_REMINDER = "clear_reminder";
const ACTION_PIN = "pin";

export default DropdownSelectBoxComponent.extend({
  classNames: ["bookmark-actions-dropdown"],
  pluginApiIdentifiers: ["bookmark-actions-dropdown"],
  selectKitOptions: {
    icon: null,
    translatedNone: "...",
    showFullTitle: true,
  },

  @discourseComputed("bookmark")
  content(bookmark) {
    const actions = [];

    actions.push({
      id: ACTION_REMOVE,
      icon: "trash-alt",
      name: I18n.t("post.bookmarks.actions.delete_bookmark.name"),
      description: I18n.t("post.bookmarks.actions.delete_bookmark.description"),
    });

    actions.push({
      id: ACTION_EDIT,
      icon: "pencil-alt",
      name: I18n.t("post.bookmarks.actions.edit_bookmark.name"),
      description: I18n.t("post.bookmarks.actions.edit_bookmark.description"),
    });

    if (bookmark.reminder_at) {
      actions.push({
        id: ACTION_CLEAR_REMINDER,
        icon: "history",
        name: I18n.t("post.bookmarks.actions.clear_bookmark_reminder.name"),
        description: I18n.t(
          "post.bookmarks.actions.clear_bookmark_reminder.description"
        ),
      });
    }

    actions.push({
      id: ACTION_PIN,
      icon: "thumbtack",
      name: I18n.t(
        `post.bookmarks.actions.${bookmark.pinAction()}_bookmark.name`
      ),
      description: I18n.t(
        `post.bookmarks.actions.${bookmark.pinAction()}_bookmark.description`
      ),
    });

    return actions;
  },

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
  },
});
