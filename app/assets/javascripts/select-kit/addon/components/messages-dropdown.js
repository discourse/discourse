import { gte, reads } from "@ember/object/computed";
import ComboBoxComponent from "select-kit/components/combo-box";
import DiscourseURL from "discourse/lib/url";
import I18n from "I18n";
import { computed } from "@ember/object";

export default ComboBoxComponent.extend({
  pluginApiIdentifiers: ["messages-dropdown"],
  classNames: ["message-dropdown"],
  content: reads("groupsWithMessages"),
  valueProperty: null,
  nameProperty: null,
  hasManyGroups: gte("content.length", 10),

  selectKitOptions: {
    caretDownIcon: "caret-right",
    caretUpIcon: "caret-down",
    filterable: "hasManyGroups",
  },

  groupsWithMessages: computed(function () {
    let groups = this.groups.filter((group) => group.hasMessages);
    groups.push(I18n.t("user.messages.inbox"));
    return groups;
  }),

  actions: {
    onChange(group) {
      if (this.groups.some((g) => g.name === group)) {
        DiscourseURL.routeToUrl(
          `/u/${this.currentUser.username}/messages/group/${group}`
        );
      } else {
        DiscourseURL.routeToUrl(`/u/${this.currentUser.username}/messages`);
      }
    },
  },
});
