import { alias, match, gt, or } from "@ember/object/computed";
import Component from "@ember/component";
import { setting } from "discourse/lib/computed";
import discourseComputed from "discourse-common/utils/decorators";
import CardContentsBase from "discourse/mixins/card-contents-base";
import CleansUp from "discourse/mixins/cleans-up";
import { groupPath } from "discourse/lib/url";
import { Promise } from "rsvp";

const maxMembersToDisplay = 10;

export default Component.extend(CardContentsBase, CleansUp, {
  elementId: "group-card",
  triggeringLinkClass: "mention-group",
  classNames: ["no-bg"],
  classNameBindings: [
    "visible:show",
    "showBadges",
    "hasCardBadgeImage",
    "isFixed:fixed",
    "groupClass"
  ],
  allowBackgrounds: setting("allow_profile_backgrounds"),
  showBadges: setting("enable_badges"),

  postStream: alias("topic.postStream"),
  viewingTopic: match("currentPath", /^topic\./),

  showMoreMembers: gt("moreMembersCount", 0),
  hasMembersOrIsMember: or(
    "group.members",
    "group.is_group_owner_display",
    "group.is_group_user"
  ),

  group: null,

  @discourseComputed("group.user_count", "group.members.length")
  moreMembersCount: (memberCount, maxMemberDisplay) =>
    memberCount - maxMemberDisplay,

  @discourseComputed("group.name")
  groupClass: name => (name ? `group-card-${name}` : ""),

  @discourseComputed("group")
  groupPath(group) {
    return groupPath(group.name);
  },

  _showCallback(username, $target) {
    this.store
      .find("group", username)
      .then(group => {
        this.setProperties({ group, visible: true });
        this._positionCard($target);
        if (!group.flair_url && !group.flair_bg_color) {
          group.set("flair_url", "fa-users");
        }
        return group.members.length < maxMembersToDisplay
          ? group.findMembers({ limit: maxMembersToDisplay }, true)
          : Promise.resolve();
      })
      .catch(() => this._close())
      .finally(() => this.set("loading", null));
  },

  _close() {
    this._super(...arguments);

    this.set("group", null);
  },

  cleanUp() {
    this._close();
  },

  actions: {
    close() {
      this._close();
    },

    cancelFilter() {
      const postStream = this.postStream;
      postStream.cancelFilter();
      postStream.refresh();
      this._close();
    },

    messageGroup() {
      this.createNewMessageViaParams(this.get("group.name"));
    },

    showGroup(group) {
      this.showGroup(group);
      this._close();
    },

    showUser(user) {
      this.showUser(user);
      this._close();
    }
  }
});
