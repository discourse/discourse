import Component from "@ember/component";
import { action } from "@ember/object";
import { alias, gt } from "@ember/object/computed";
import { service } from "@ember/service";
import { setting } from "discourse/lib/computed";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import { groupPath } from "discourse/lib/url";
import CardContentsBase from "discourse/mixins/card-contents-base";
import CleansUp from "discourse/mixins/cleans-up";
import discourseComputed from "discourse-common/utils/decorators";

const maxMembersToDisplay = 10;

export default Component.extend(CardContentsBase, CleansUp, {
  composer: service(),

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

  @discourseComputed("group.members.[]")
  highlightedMembers(members) {
    return members.slice(0, maxMembersToDisplay);
  },

  @discourseComputed("group.user_count", "group.members.[]")
  moreMembersCount(memberCount) {
    return Math.max(memberCount - maxMembersToDisplay, 0);
  },

  @discourseComputed("group.name")
  groupClass: (name) => (name ? `group-card-${name}` : ""),

  @discourseComputed("group")
  groupPath(group) {
    return groupPath(group.name);
  },

  async _showCallback(username) {
    this.setProperties({ visible: true, loading: true });

    try {
      const group = await this.store.find("group", username);
      this.setProperties({ group });

      if (!group.flair_url && !group.flair_bg_color) {
        group.set("flair_url", "fa-users");
      }

      if (group.can_see_members && group.members.length < maxMembersToDisplay) {
        return group.reloadMembers({ limit: maxMembersToDisplay }, true);
      }
    } catch {
      this._close();
    } finally {
      this.set("loading", null);
    }
  },

  _close() {
    this.set("group", null);

    this._super(...arguments);
  },

  cleanUp() {
    this._close();
  },

  @action
  close(event) {
    event?.preventDefault();
    this._close();
  },

  @action
  handleShowGroup(event) {
    if (wantsNewWindow(event)) {
      return;
    }

    event.preventDefault();
    // Invokes `showGroup` argument. Convert to `this.args.showGroup` when
    // refactoring this to a glimmer component.
    this.showGroup(this.group);
    this._close();
  },

  actions: {
    cancelFilter() {
      this.postStream.cancelFilter();
      this.postStream.refresh();
      this._close();
    },

    messageGroup() {
      this.composer.openNewMessage({
        recipients: this.get("group.name"),
        hasGroups: true,
      });
    },
  },
});
