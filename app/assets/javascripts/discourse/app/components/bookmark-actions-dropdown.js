import { action } from "@ember/object";
import discourseComputed from "discourse-common/utils/decorators";
import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import I18n from "I18n";

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
    let pinVerb = bookmark.pinned ? "unpin" : "pin";
    return [
      {
        id: "remove",
        icon: "trash-alt",
        name: I18n.t("post.bookmarks.actions.delete_bookmark.name"),
        description: I18n.t(
          "post.bookmarks.actions.delete_bookmark.description"
        ),
      },
      {
        id: "edit",
        icon: "pencil-alt",
        name: I18n.t("post.bookmarks.actions.edit_bookmark.name"),
        description: I18n.t("post.bookmarks.actions.edit_bookmark.description"),
      },
      {
        id: "pin",
        icon: "thumbtack",
        name: I18n.t(`post.bookmarks.actions.${pinVerb}_bookmark.name`),
        description: I18n.t(
          `post.bookmarks.actions.${pinVerb}_bookmark.description`
        ),
      },
    ];
  },

  @action
  onChange(selectedAction) {
    if (selectedAction === "remove") {
      this.removeBookmark(this.bookmark);
    } else if (selectedAction === "edit") {
      this.editBookmark(this.bookmark);
    } else if (selectedAction === "pin") {
      this.togglePinBookmark(this.bookmark);
    }
  },
});
