import { setting } from "discourse/lib/computed";
import { default as computed } from "ember-addons/ember-computed-decorators";
import CardContentsBase from "discourse/mixins/card-contents-base";
import CleansUp from "discourse/mixins/cleans-up";

const maxMembersToDisplay = 10;

export default Ember.Component.extend(CardContentsBase, CleansUp, {
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

  postStream: Ember.computed.alias("topic.postStream"),
  viewingTopic: Ember.computed.match("currentPath", /^topic\./),

  showMoreMembers: Ember.computed.gt("moreMembersCount", 0),

  group: null,

  @computed("group.user_count", "group.members.length")
  moreMembersCount: (memberCount, maxMemberDisplay) =>
    memberCount - maxMemberDisplay,

  @computed("group.name")
  groupClass: name => (name ? `group-card-${name}` : ""),

  @computed("group")
  groupPath(group) {
    return `${Discourse.BaseUri}/groups/${group.name}`;
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
        group.set("limit", maxMembersToDisplay);
        return group.findMembers();
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
      const postStream = this.get("postStream");
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
    }
  }
});
