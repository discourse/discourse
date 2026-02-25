import { tracked } from "@glimmer/tracking";
import { action, computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import DiscourseURL from "discourse/lib/url";
import ComboBoxComponent from "discourse/select-kit/components/combo-box";
import {
  pluginApiIdentifiers,
  selectKitOptions,
} from "discourse/select-kit/components/select-kit";
import { i18n } from "discourse-i18n";

@classNames("group-dropdown")
@selectKitOptions({
  caretDownIcon: "angle-right",
  caretUpIcon: "angle-down",
  filterable: "hasManyGroups",
})
@pluginApiIdentifiers("group-dropdown")
export default class GroupDropdown extends ComboBoxComponent {
  valueProperty = null;
  nameProperty = null;

  @tracked _contentOverride;

  @computed("groupsWithShortcut")
  get content() {
    if (this._contentOverride !== undefined) {
      return this._contentOverride;
    }
    return this.groupsWithShortcut;
  }

  set content(value) {
    this._contentOverride = value;
  }

  @computed("content.length")
  get hasManyGroups() {
    return this.content?.length >= 10;
  }

  @computed("siteSettings.enable_group_directory")
  get enableGroupDirectory() {
    return this.siteSettings.enable_group_directory;
  }

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
