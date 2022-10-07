import { gte, reads } from "@ember/object/computed";
import ComboBoxComponent from "select-kit/components/combo-box";
import DiscourseURL from "discourse/lib/url";
import I18n from "I18n";
import { computed } from "@ember/object";

export default ComboBoxComponent.extend({
  pluginApiIdentifiers: ["messages-dropdown"],
  classNames: ["message-dropdown"],
  content: reads("groupsWithMessages"),
  valueProperty: "name",
  hasManyGroups: gte("content.length", 10),

  selectKitOptions: {
    caretDownIcon: "caret-right",
    caretUpIcon: "caret-down",
    filterable: "hasManyGroups",
  },

  groupsWithMessages: computed(function () {
    const groups = [
      {
        name: I18n.t("user.messages.inbox"),
      },
    ];

    this.user.groupsWithMessages.forEach((group) => {
      groups.push({ name: group.name, icon: "inbox" });
    });

    if (this.pmTaggingEnabled) {
      groups.push({ name: I18n.t("user.messages.tags") });
    }

    return groups;
  }),

  actions: {
    onChange(item) {
      let url;

      if (this.user.groups.some((g) => g.name === item)) {
        url = `/u/${this.user.username}/messages/group/${item}`;
      } else if (item === I18n.t("user.messages.tags")) {
        url = `/u/${this.user.username}/messages/tags`;
      } else {
        url = `/u/${this.user.username}/messages`;
      }

      DiscourseURL.routeToUrl(url);
    },
  },
});
