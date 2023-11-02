import { computed } from "@ember/object";
import I18n from "discourse-i18n";
import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";

export default DropdownSelectBoxComponent.extend({
  pluginApiIdentifiers: ["tags-admin-dropdown"],
  classNames: ["tags-admin-dropdown"],
  actionsMapping: null,

  selectKitOptions: {
    icons: ["wrench", "caret-down"],
    showFullTitle: false,
  },

  content: computed(function () {
    return [
      {
        id: "manageGroups",
        name: I18n.t("tagging.manage_groups"),
        description: I18n.t("tagging.manage_groups_description"),
        icon: "tags",
      },
      {
        id: "uploadTags",
        name: I18n.t("tagging.upload"),
        description: I18n.t("tagging.upload_description"),
        icon: "upload",
      },
      {
        id: "deleteUnusedTags",
        name: I18n.t("tagging.delete_unused"),
        description: I18n.t("tagging.delete_unused_description"),
        icon: "trash-alt",
      },
    ];
  }),

  actions: {
    onChange(id) {
      const action = this.actionsMapping[id];

      if (action) {
        action();
      }
    },
  },
});
