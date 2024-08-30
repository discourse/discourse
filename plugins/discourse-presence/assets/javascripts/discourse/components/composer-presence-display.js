import Component from "@ember/component";
import { equal, gt, readOnly, union } from "@ember/object/computed";
import { service } from "@ember/service";
import { tagName } from "@ember-decorators/component";
import { observes, on } from "@ember-decorators/object";
import discourseComputed from "discourse-common/utils/decorators";

@tagName("")
export default class ComposerPresenceDisplay extends Component {
  @service presence;
  @service composerPresenceManager;

  @equal("state", "reply") isReply;
  @equal("state", "edit") isEdit;
  @equal("state", "whisper") isWhisper;
  @union("replyChannel.users", "whisperChannel.users") replyingUsers;
  @readOnly("editChannel.users") editingUsers;
  @gt("presenceUsers.length", 0) shouldDisplay;

  @discourseComputed(
    "model.replyingToTopic",
    "model.editingPost",
    "model.whisper",
    "model.composerOpened"
  )
  state(replyingToTopic, editingPost, whisper, composerOpen) {
    if (!composerOpen) {
      return;
    } else if (editingPost) {
      return "edit";
    } else if (whisper) {
      return "whisper";
    } else if (replyingToTopic) {
      return "reply";
    }
  }

  @discourseComputed("model.topic.id", "isReply", "isWhisper")
  replyChannelName(topicId, isReply, isWhisper) {
    if (topicId && (isReply || isWhisper)) {
      return `/discourse-presence/reply/${topicId}`;
    }
  }

  @discourseComputed("model.topic.id", "isReply", "isWhisper")
  whisperChannelName(topicId, isReply, isWhisper) {
    if (topicId && this.currentUser.whisperer && (isReply || isWhisper)) {
      return `/discourse-presence/whisper/${topicId}`;
    }
  }

  @discourseComputed("isEdit", "model.post.id")
  editChannelName(isEdit, postId) {
    if (isEdit) {
      return `/discourse-presence/edit/${postId}`;
    }
  }

  _setupChannel(channelKey, name) {
    if (this[channelKey]?.name !== name) {
      this[channelKey]?.unsubscribe();
      if (name) {
        this.set(channelKey, this.presence.getChannel(name));
        this[channelKey].subscribe();
      } else if (this[channelKey]) {
        this.set(channelKey, null);
      }
    }
  }

  @observes("replyChannelName", "whisperChannelName", "editChannelName")
  _setupChannels() {
    this._setupChannel("replyChannel", this.replyChannelName);
    this._setupChannel("whisperChannel", this.whisperChannelName);
    this._setupChannel("editChannel", this.editChannelName);
  }

  _cleanupChannels() {
    this._setupChannel("replyChannel", null);
    this._setupChannel("whisperChannel", null);
    this._setupChannel("editChannel", null);
  }

  @discourseComputed("isReply", "replyingUsers.[]", "editingUsers.[]")
  presenceUsers(isReply, replyingUsers, editingUsers) {
    const users = isReply ? replyingUsers : editingUsers;
    return users
      ?.filter((u) => u.id !== this.currentUser.id)
      ?.slice(0, this.siteSettings.presence_max_users_shown);
  }

  @on("didInsertElement")
  subscribe() {
    this._setupChannels();
  }

  @observes("model.reply", "state", "model.post.id", "model.topic.id")
  _contentChanged() {
    if (this.model.reply === "") {
      return;
    }
    const entity = this.state === "edit" ? this.model?.post : this.model?.topic;
    this.composerPresenceManager.notifyState(this.state, entity?.id);
  }

  @on("willDestroyElement")
  closeComposer() {
    this._cleanupChannels();
    this.composerPresenceManager.leave();
  }
}
