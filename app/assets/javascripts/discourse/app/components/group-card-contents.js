import { alias, gt } from "@ember/object/computed";
import CardContentsBase from "discourse/mixins/card-contents-base";
import CleansUp from "discourse/mixins/cleans-up";
import Component from "@ember/component";
import { Promise } from "rsvp";
import discourseComputed from "discourse-common/utils/decorators";
import { groupPath } from "discourse/lib/url";
import { setting } from "discourse/lib/computed";

const maxMembersToDisplay = 10;

export default Component.extend(CardContentsBase, CleansUp, {
  elementId: "group-card",
  mentionSelector: "a.mention-group",
  classNames: ["no-bg", "group-card"],
  classNameBindings: [
    "visible:show",
    "showBadges",
    "hasCardBadgeImage",
    "isFixed:fixed",
    "groupClass",
  ],
  allowBackgrounds: setting("allow_profile_backgrounds"),
  showBadges: setting("enable_badges"),

  postStream: alias("topic.postStream"),
  showMoreMembers: gt("moreMembersCount", 0),

  group: null,

  @discourseComputed("group.user_count", "group.members.length")
  moreMembersCount: (memberCount, maxMemberDisplay) =>
    memberCount - maxMemberDisplay,

  @discourseComputed("group.name")
  groupClass: (name) => (name ? `group-card-${name}` : ""),

  @discourseComputed("group")
  groupPath(group) {
    return groupPath(group.name);
  },

  _showCallback(username, $target) {
    this._positionCard($target);
    this.setProperties({ visible: true, loading: true });

    return this.store
      .find("group", username)
      .then((group) => {
        this.setProperties({ group });
        if (!group.flair_url && !group.flair_bg_color) {
          group.set("flair_url", "fa-users");
        }
        return group.can_see_members &&
          group.members.length < maxMembersToDisplay
          ? group.reloadMembers({ limit: maxMembersToDisplay }, true)
          : Promise.resolve();
      })
      .catch(() => this._close())
      .finally(() => this.set("loading", null));
  },

  _close() {
    this.set("group", null);

    this._super(...arguments);
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
      this.createNewMessageViaParams({
        recipients: this.get("group.name"),
        hasGroups: true,
      });
    },

    showGroup(group) {
      this.showGroup(group);
      this._close();
    },
  },
});
