import { reads, gte } from "@ember/object/computed";
import ComboBoxComponent from "select-kit/components/combo-box";
import DiscourseURL from "discourse/lib/url";
import { computed } from "@ember/object";
import { setting } from "discourse/lib/computed";

export default ComboBoxComponent.extend({
  pluginApiIdentifiers: ["group-dropdown"],
  classNames: ["group-dropdown"],
  content: reads("groupsWithShortcut"),
  tagName: "li",
  valueProperty: null,
  nameProperty: null,
  hasManyGroups: gte("content.length", 10),
  enableGroupDirectory: setting("enable_group_directory"),

  selectKitOptions: {
    caretDownIcon: "caret-right",
    caretUpIcon: "caret-down",
    filterable: "hasManyGroups"
  },

  groupsWithShortcut: computed("groups.[]", function() {
    const shortcuts = [];

    if (this.enableGroupDirectory || this.get("currentUser.staff")) {
      shortcuts.push(I18n.t("groups.index.all").toLowerCase());
    }

    return shortcuts.concat(this.groups);
  }),

  actions: {
    onChange(groupName) {
      if ((this.groups || []).includes(groupName)) {
        DiscourseURL.routeToUrl(`/g/${groupName}`);
      } else {
        DiscourseURL.routeToUrl(`/g`);
      }
    }
  }
});
