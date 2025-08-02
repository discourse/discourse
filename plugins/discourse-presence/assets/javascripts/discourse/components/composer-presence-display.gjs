import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { gt } from "truth-helpers";
import UserLink from "discourse/components/user-link";
import avatar from "discourse/helpers/avatar";
import helperFn from "discourse/helpers/helper-fn";
import { i18n } from "discourse-i18n";

export default class ComposerPresenceDisplay extends Component {
  @service presence;
  @service composerPresenceManager;
  @service currentUser;
  @service siteSettings;

  @tracked replyChannel;
  @tracked whisperChannel;
  @tracked editChannel;

  setupReplyChannel = helperFn((_, on) => {
    const { topic } = this.args.model;

    if (!topic || !this.isReply) {
      return;
    }

    const name = `/discourse-presence/reply/${topic.id}`;
    const replyChannel = this.presence.getChannel(name);
    this.replyChannel = replyChannel;

    replyChannel.subscribe();
    on.cleanup(() => replyChannel.unsubscribe());
  });

  setupWhisperChannel = helperFn((_, on) => {
    const { topic } = this.args.model;
    const { whisperer } = this.currentUser;

    if (!topic || !this.isReply || !whisperer) {
      return;
    }

    const name = `/discourse-presence/whisper/${topic.id}`;
    const whisperChannel = this.presence.getChannel(name);
    this.whisperChannel = whisperChannel;

    whisperChannel.subscribe();
    on.cleanup(() => whisperChannel.unsubscribe());
  });

  setupEditChannel = helperFn((_, on) => {
    const { post } = this.args.model;

    if (!post || !this.isEdit) {
      return;
    }

    const name = `/discourse-presence/edit/${post.id}`;
    const editChannel = this.presence.getChannel(name);
    this.editChannel = editChannel;

    editChannel.subscribe();
    on.cleanup(() => editChannel.unsubscribe());
  });

  notifyState = helperFn((_, on) => {
    const { topic, post, replyDirty } = this.args.model;
    const entity = this.isEdit ? post : topic;

    if (entity) {
      const name = `/discourse-presence/${this.state}/${entity.id}`;
      this.composerPresenceManager.notifyState(name, replyDirty);
    }

    on.cleanup(() => this.composerPresenceManager.leave());
  });

  get isReply() {
    return this.state === "reply" || this.state === "whisper";
  }

  get isEdit() {
    return this.state === "edit";
  }

  @cached
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

  @cached
  get users() {
    let users;

    if (this.isEdit) {
      users = this.editChannel?.users || [];
    } else {
      const replyUsers = this.replyChannel?.users || [];
      const whisperUsers = this.whisperChannel?.users || [];
      users = [...replyUsers, ...whisperUsers];
    }

    return users
      .filter((u) => u.id !== this.currentUser.id)
      .slice(0, this.siteSettings.presence_max_users_shown);
  }

  <template>
    {{#if this.currentUser}}
      {{this.setupReplyChannel}}
      {{this.setupWhisperChannel}}
      {{this.setupEditChannel}}
      {{this.notifyState}}

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
    {{/if}}
  </template>
}
