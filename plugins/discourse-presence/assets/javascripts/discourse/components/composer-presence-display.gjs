import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import { gt } from "truth-helpers";
import UserLink from "discourse/components/user-link";
import avatar from "discourse/helpers/avatar";
import i18n from "discourse-common/helpers/i18n";

export default class ComposerPresenceDisplayComponent extends Component {
  @service presence;
  @service composerPresenceManager;
  @service currentUser;
  @service siteSettings;

  @tracked replyChannel;
  @tracked whisperChannel;
  @tracked editChannel;

  setupChannels = modifier(() => {
    this.setupChannel("replyChannel", this.replyChannelName);
    if (this.currentUser.staff) {
      this.setupChannel("whisperChannel", this.whisperChannelName);
    }
    this.setupChannel("editChannel", this.editChannelName);

    const { reply, post, topic } = this.args.model;
    const raw = this.isEdit ? post?.raw || "" : "";
    const entity = this.isEdit ? post : topic;

    if (reply !== raw) {
      this.composerPresenceManager.notifyState(this.state, entity?.id);
    }

    return () => {
      this.replyChannel?.unsubscribe();
      this.whisperChannel?.unsubscribe();
      this.editChannel?.unsubscribe();
      this.composerPresenceManager.leave();
    };
  });

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
    const topicId = this.args.model.topic?.id;
    if (topicId && this.isReply) {
      return `/discourse-presence/reply/${topicId}`;
    }
  }

  get whisperChannelName() {
    const topicId = this.args.model.topic?.id;
    if (topicId && this.isReply && this.currentUser.whisperer) {
      return `/discourse-presence/whisper/${topicId}`;
    }
  }

  get editChannelName() {
    const postId = this.args.model.post?.id;
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

  setupChannel(key, name) {
    if (name) {
      this[key] = this.presence.getChannel(name);
      this[key].subscribe();
    }
  }

  <template>
    <div {{this.setupChannels}}>
      {{#if (gt this.users.length 0)}}
        <div class="presence-users">
          <div class="presence-avatars">
            {{#each this.users as |user|}}
              <UserLink @user={{user}}>
                {{avatar user imageSize="small"}}
              </UserLink>
            {{/each}}
          </div>

          <span class="presence-text">
            <span class="description">
              {{~#if this.isReply~}}
                {{i18n "presence.replying" count=this.users.length}}
              {{~else~}}
                {{i18n "presence.editing" count=this.users.length}}
              {{~/if~}}
            </span>
            <span class="wave">
              <span class="dot">.</span>
              <span class="dot">.</span>
              <span class="dot">.</span>
            </span>
          </span>
        </div>
      {{/if}}
    </div>
  </template>
}
