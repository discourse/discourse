import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import { computed } from "@ember/object";

export default DropdownSelectBoxComponent.extend({
  pluginApiIdentifiers: ["tags-admin-dropdown"],
  classNames: ["tags-admin-dropdown"],
  actionsMapping: null,

  selectKitOptions: {
    icons: ["bars", "caret-down"],
    showFullTitle: false
  },

  content: computed(function() {
    return [
      {
        id: "manageGroups",
        name: I18n.t("tagging.manage_groups"),
        description: I18n.t("tagging.manage_groups_description"),
        icon: "wrench"
      },
      {
        id: "uploadTags",
        name: I18n.t("tagging.upload"),
        description: I18n.t("tagging.upload_description"),
        icon: "upload"
      },
      {
        id: "deleteUnusedTags",
        name: I18n.t("tagging.delete_unused"),
        description: I18n.t("tagging.delete_unused_description"),
        icon: "trash-alt"
      }
    ];
  }),

  actions: {
    onChange(id) {
      const action = this.actionsMapping[id];

      if (action) {
        action();
      }
    }
  }
});
