import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";

export default class ComposerPresenceDisplayComponent extends Component {
  @service presence;
  @service composerPresenceManager;
  @service currentUser;
  @service siteSettings;

  @tracked replyChannel;
  @tracked whisperChannel;
  @tracked editChannel;

  get isReply() {
    return this.state === "reply" || this.state === "whisper";
  }

  get isEdit() {
    return this.state === "edit";
  }

  get state() {
    const { editingPost, whisper, replyingToTopic } = this.args.model;

    if (editingPost) {
      return "edit";
    } else if (whisper) {
      return "whisper";
    } else if (replyingToTopic) {
      return "reply";
    }
  }

  get replyChannelName() {
    const topicId = this.args.model?.topic?.id;
    if (topicId && this.isReply) {
      return `/discourse-presence/reply/${topicId}`;
    }
  }

  get whisperChannelName() {
    const topicId = this.args.model?.topic?.id;
    if (topicId && this.isReply && this.currentUser.whisperer) {
      return `/discourse-presence/whisper/${topicId}`;
    }
  }

  get editChannelName() {
    const postId = this.args.model?.post?.id;
    if (postId && this.isEdit) {
      return `/discourse-presence/edit/${postId}`;
    }
  }

  get replyUsers() {
    return this.replyChannel?.users || [];
  }

  get whisperUsers() {
    return this.whisperChannel?.users || [];
  }

  get replyingUsers() {
    return [...this.replyUsers, ...this.whisperUsers];
  }

  get editingUsers() {
    return this.editChannel?.users || [];
  }

  get users() {
    const users = this.isEdit ? this.editingUsers : this.replyingUsers;
    return users
      .filter((u) => u.id !== this.currentUser.id)
      .slice(0, this.siteSettings.presence_max_users_shown);
  }

  get shouldDisplay() {
    return this.users.length > 0;
  }

  @action
  setupChannels() {
    this.setupReplyChannel();
    this.setupWhisperChannel();
    this.setupEditChannel();
    this.notifyState();
  }

  setupReplyChannel() {
    this.setupChannel("replyChannel", this.replyChannelName);
  }

  setupWhisperChannel() {
    if (this.currentUser.staff) {
      this.setupChannel("whisperChannel", this.whisperChannelName);
    }
  }

  setupEditChannel() {
    this.setupChannel("editChannel", this.editChannelName);
  }

  setupChannel(key, name) {
    if (this[key]?.name !== name) {
      this[key]?.unsubscribe();
      if (name) {
        this[key] = this.presence.getChannel(name);
        this[key].subscribe();
      }
    }
  }

  notifyState() {
    const { reply, post, topic } = this.args.model;
    const raw = this.isEdit ? post?.raw || "" : "";
    const entity = this.isEdit ? post : topic;

    if (reply !== raw) {
      this.composerPresenceManager.notifyState(this.state, entity?.id);
    }
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.unsubscribeFromChannels();
    this.composerPresenceManager.leave();
  }

  unsubscribeFromChannels() {
    this.replyChannel?.unsubscribe();
    this.whisperChannel?.unsubscribe();
    this.editChannel?.unsubscribe();
  }
}
