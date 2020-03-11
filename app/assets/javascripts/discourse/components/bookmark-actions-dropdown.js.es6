import { computed } from "@ember/object";
import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import { action } from "@ember/object";

export default DropdownSelectBoxComponent.extend({
  classNames: ["bookmark-actions-dropdown"],
  pluginApiIdentifiers: ["bookmark-actions-dropdown"],
  selectKitOptions: {
    icon: null,
    translatedNone: "...",
    showFullTitle: true
  },

  content: computed(() => {
    return [
      {
        id: "remove",
        icon: "trash-alt",
        name: I18n.t("post.bookmarks.actions.delete_bookmark.name"),
        description: I18n.t(
          "post.bookmarks.actions.delete_bookmark.description"
        )
      }
    ];
  }),

  @action
  onChange(selectedAction) {
    if (selectedAction === "remove") {
      this.removeBookmark(this.bookmark);
    }
  }
});
