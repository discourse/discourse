import { action, computed } from "@ember/object";
import { gte, reads } from "@ember/object/computed";
import { classNames } from "@ember-decorators/component";
import { setting } from "discourse/lib/computed";
import DiscourseURL from "discourse/lib/url";
import { i18n } from "discourse-i18n";
import ComboBoxComponent from "select-kit/components/combo-box";
import {
  pluginApiIdentifiers,
  selectKitOptions,
} from "select-kit/components/select-kit";

@classNames("group-dropdown")
@selectKitOptions({
  caretDownIcon: "caret-right",
  caretUpIcon: "caret-down",
  filterable: "hasManyGroups",
})
@pluginApiIdentifiers("group-dropdown")
export default class GroupDropdown extends ComboBoxComponent {
  @reads("groupsWithShortcut") content;
  @gte("content.length", 10) hasManyGroups;
  @setting("enable_group_directory") enableGroupDirectory;

  valueProperty = null;
  nameProperty = null;

  @computed("groups.[]")
  get groupsWithShortcut() {
    const shortcuts = [];

    if (this.enableGroupDirectory || this.get("currentUser.staff")) {
      shortcuts.push(i18n("groups.index.all"));
    }

    return shortcuts.concat(this.groups);
  }

  @action
  onChange(groupName) {
    if ((this.groups || []).includes(groupName)) {
      DiscourseURL.routeToUrl(`/g/${groupName}`);
    } else {
      DiscourseURL.routeToUrl(`/g`);
    }
  }
}
