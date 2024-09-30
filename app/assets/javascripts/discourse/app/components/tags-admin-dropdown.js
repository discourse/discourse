import { action, computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import I18n from "discourse-i18n";
import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import {
  pluginApiIdentifiers,
  selectKitOptions,
} from "select-kit/components/select-kit";

@classNames("tags-admin-dropdown")
@selectKitOptions({
  icons: ["wrench", "caret-down"],
  showFullTitle: false,
})
@pluginApiIdentifiers("tags-admin-dropdown")
export default class TagsAdminDropdown extends DropdownSelectBoxComponent {
  actionsMapping = null;

  @computed
  get content() {
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
        icon: "trash-can",
      },
    ];
  }

  @action
  onChange(id) {
    this.actionsMapping[id]?.();
  }
}
