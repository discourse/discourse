import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";

export default DropdownSelectBoxComponent.extend({
  classNames: ["bookmark-actions-dropdown"],
  headerIcon: null,
  title: "...",
  showFullTitle: true,

  computeContent() {
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
  },

  actions: {
    onSelect(id) {
      switch (id) {
        case "remove":
          this.removeBookmark(this.bookmarkId);
          break;
      }
    }
  }
});
