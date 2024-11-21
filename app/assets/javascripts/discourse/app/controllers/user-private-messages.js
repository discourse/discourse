import { cached, tracked } from "@glimmer/tracking";
import Controller, { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import { alias, and, equal, readOnly } from "@ember/object/computed";
import { service } from "@ember/service";
import DiscourseURL from "discourse/lib/url";
import { i18n } from "discourse-i18n";

const customUserNavMessagesDropdownRows = [];

export function registerCustomUserNavMessagesDropdownRow(
  routeName,
  name,
  icon
) {
  customUserNavMessagesDropdownRows.push({
    routeName,
    name,
    icon,
  });
}

export function resetCustomUserNavMessagesDropdownRows() {
  customUserNavMessagesDropdownRows.length = 0;
}

export default class extends Controller {
  @service router;
  @controller user;
  @controller userTopicsList;

  @tracked group;
  @tracked tagId;

  @alias("group.name") groupFilter;
  @and("user.viewingSelf", "currentUser.can_send_private_messages") showNewPM;
  @equal("currentParentRouteName", "userPrivateMessages.group") isGroup;
  @readOnly("user.viewingSelf") viewingSelf;
  @readOnly("router.currentRoute.parent.name") currentParentRouteName;
  @readOnly("site.can_tag_pms") pmTaggingEnabled;

  get bulkSelectHelper() {
    return this.userTopicsList.bulkSelectHelper;
  }

  get messagesDropdownValue() {
    let value;

    const currentURL = this.router.currentURL.toLowerCase();

    for (let i = this.messagesDropdownContent.length - 1; i >= 0; i--) {
      const row = this.messagesDropdownContent[i];

      if (
        currentURL.includes(
          row.id.toLowerCase().replace(this.router.rootURL, "/")
        )
      ) {
        value = row.id;
        break;
      }
    }

    return value;
  }

  @cached
  get messagesDropdownContent() {
    const usernameLower = this.model.username_lower;

    const content = [
      {
        id: this.router.urlFor("userPrivateMessages.user", usernameLower),
        name: i18n("user.messages.inbox"),
      },
    ];

    this.model.groupsWithMessages.forEach((group) => {
      content.push({
        id: this.router.urlFor(
          "userPrivateMessages.group",
          usernameLower,
          group.name
        ),
        name: group.name,
        icon: "inbox",
      });
    });

    if (this.pmTaggingEnabled) {
      content.push({
        id: this.router.urlFor("userPrivateMessages.tags", usernameLower),
        name: i18n("user.messages.tags"),
        icon: "tags",
      });
    }

    customUserNavMessagesDropdownRows.forEach((row) => {
      content.push({
        id: this.router.urlFor(row.routeName, usernameLower),
        name: row.name,
        icon: row.icon,
      });
    });

    return content;
  }

  @action
  onMessagesDropdownChange(item) {
    return DiscourseURL.routeTo(item);
  }
}
