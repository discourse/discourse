import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";

export default class TopicPresenceDisplayComponent extends Component {
  @service presence;
  @service currentUser;

  @tracked replyChannel;
  @tracked whisperChannel;

  get replyChannelName() {
    return `/discourse-presence/reply/${this.args.topic.id}`;
  }

  get whisperChannelName() {
    return `/discourse-presence/whisper/${this.args.topic.id}`;
  }

  get replyUsers() {
    return this.replyChannel?.users || [];
  }

  get whisperUsers() {
    return this.whisperChannel?.users || [];
  }

  get users() {
    return [...this.replyUsers, ...this.whisperUsers].filter(
      (u) => u.id !== this.currentUser.id
    );
  }

  get shouldDisplay() {
    return this.users.length > 0;
  }

  @action
  setupChannels() {
    this.setupReplyChannel();
    this.setupWhisperChannel();
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.unsubscribeFromChannels();
  }

  unsubscribeFromChannels() {
    this.replyChannel?.unsubscribe();
    this.whisperChannel?.unsubscribe();
  }

  setupReplyChannel() {
    if (this.replyChannel?.name !== this.replyChannelName) {
      this.replyChannel?.unsubscribe();
      this.replyChannel = this.presence.getChannel(this.replyChannelName);
      this.replyChannel.subscribe();
    }
  }

  setupWhisperChannel() {
    if (this.currentUser.staff) {
      if (this.whisperChannel?.name !== this.whisperChannelName) {
        this.whisperChannel?.unsubscribe();
        this.whisperChannel = this.presence.getChannel(this.whisperChannelName);
        this.whisperChannel.subscribe();
      }
    }
  }
}
