import Component from "@ember/component";
import { gt, union } from "@ember/object/computed";
import { service } from "@ember/service";
import { on } from "@ember-decorators/object";
import discourseComputed from "discourse-common/utils/decorators";

export default class TopicPresenceDisplay extends Component {
  @service presence;

  topic = null;
  replyChannel = null;
  whisperChannel = null;

  @union("replyUsers", "whisperUsers") users;
  @gt("users.length", 0) shouldDisplay;

  @discourseComputed("replyChannel.users.[]")
  replyUsers(users) {
    return users?.filter((u) => u.id !== this.currentUser.id);
  }

  @discourseComputed("whisperChannel.users.[]")
  whisperUsers(users) {
    return users?.filter((u) => u.id !== this.currentUser.id);
  }

  @discourseComputed("topic.id")
  replyChannelName(id) {
    return `/discourse-presence/reply/${id}`;
  }

  @discourseComputed("topic.id")
  whisperChannelName(id) {
    return `/discourse-presence/whisper/${id}`;
  }

  didReceiveAttrs() {
    super.didReceiveAttrs(...arguments);

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
  }

  @on("willDestroyElement")
  _destroyed() {
    this.replyChannel?.unsubscribe();
    this.whisperChannel?.unsubscribe();
  }
}
