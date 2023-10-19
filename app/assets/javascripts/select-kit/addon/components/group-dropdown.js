import { computed } from "@ember/object";
import { gte, reads } from "@ember/object/computed";
import { setting } from "discourse/lib/computed";
import DiscourseURL from "discourse/lib/url";
import I18n from "discourse-i18n";
import ComboBoxComponent from "select-kit/components/combo-box";

export default ComboBoxComponent.extend({
  pluginApiIdentifiers: ["group-dropdown"],
  classNames: ["group-dropdown"],
  content: reads("groupsWithShortcut"),
  valueProperty: null,
  nameProperty: null,
  hasManyGroups: gte("content.length", 10),
  enableGroupDirectory: setting("enable_group_directory"),

  selectKitOptions: {
    caretDownIcon: "caret-right",
    caretUpIcon: "caret-down",
    filterable: "hasManyGroups",
  },

  groupsWithShortcut: computed("groups.[]", function () {
    const shortcuts = [];

    if (this.enableGroupDirectory || this.get("currentUser.staff")) {
      shortcuts.push(I18n.t("groups.index.all"));
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
    },
  },
});
