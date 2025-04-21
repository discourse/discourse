import { action, computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import { i18n } from "discourse-i18n";
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
        name: i18n("tagging.manage_groups"),
        description: i18n("tagging.manage_groups_description"),
        icon: "tags",
      },
      {
        id: "uploadTags",
        name: i18n("tagging.upload"),
        description: i18n("tagging.upload_description"),
        icon: "upload",
      },
      {
        id: "deleteUnusedTags",
        name: i18n("tagging.delete_unused"),
        description: i18n("tagging.delete_unused_description"),
        icon: "trash-can",
      },
    ];
  }

  @action
  onChange(id) {
    this.actionsMapping[id]?.();
  }
}
