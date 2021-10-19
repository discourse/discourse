import discourseComputed, { on } from "discourse-common/utils/decorators";
import Component from "@ember/component";
import { gt, union } from "@ember/object/computed";
import { inject as service } from "@ember/service";

export default Component.extend({
  topic: null,
  presence: service(),
  replyChannel: null,
  whisperChannel: null,

  @discourseComputed("replyChannel.users.[]")
  replyUsers(users) {
    return users?.filter((u) => u.id !== this.currentUser.id);
  },

  @discourseComputed("whisperChannel.users.[]")
  whisperUsers(users) {
    return users?.filter((u) => u.id !== this.currentUser.id);
  },

  users: union("replyUsers", "whisperUsers"),

  @discourseComputed("topic.id")
  replyChannelName(id) {
    return `/discourse-presence/reply/${id}`;
  },

  @discourseComputed("topic.id")
  whisperChannelName(id) {
    return `/discourse-presence/whisper/${id}`;
  },

  shouldDisplay: gt("users.length", 0),

  didReceiveAttrs() {
    this._super(...arguments);

    if (this.replyChannel?.name !== this.replyChannelName) {
      this.replyChannel?.unsubscribe();
      this.set("replyChannel", this.presence.getChannel(this.replyChannelName));
      this.replyChannel.subscribe();
    }

    if (
      this.currentUser.staff &&
      this.whisperChannel?.name !== this.whisperChannelName
    ) {
      this.whisperChannel?.unsubscribe();
      this.set(
        "whisperChannel",
        this.presence.getChannel(this.whisperChannelName)
      );
      this.whisperChannel.subscribe();
    }
  },

  @on("willDestroyElement")
  _destroyed() {
    this.replyChannel?.unsubscribe();
    this.whisperChannel?.unsubscribe();
  },
});
