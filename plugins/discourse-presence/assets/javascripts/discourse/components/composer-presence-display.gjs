import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import { gt } from "truth-helpers";
import UserLink from "discourse/components/user-link";
import avatar from "discourse/helpers/avatar";
import i18n from "discourse-common/helpers/i18n";

export default class ComposerPresenceDisplay extends Component {
  @service presence;
  @service composerPresenceManager;
  @service currentUser;
  @service siteSettings;

  @tracked replyChannel;
  @tracked whisperChannel;
  @tracked editChannel;

  setupReplyChannel = modifier(() => {
    const topic = this.args.model.topic;
    if (!topic || !this.isReply) {
      return;
    }

    const replyChannel = this.presence.getChannel(
      `/discourse-presence/reply/${topic.id}`
    );
    replyChannel.subscribe();
    this.replyChannel = replyChannel;

    return () => replyChannel.unsubscribe();
  });

  setupWhisperChannel = modifier(() => {
    if (
      !this.args.model.topic ||
      !this.isReply ||
      !this.currentUser.staff ||
      !this.currentUser.whisperer
    ) {
      return;
    }

    const whisperChannel = this.presence.getChannel(
      `/discourse-presence/whisper/${this.args.model.topic.id}`
    );
    whisperChannel.subscribe();
    this.whisperChannel = whisperChannel;

    return () => whisperChannel.unsubscribe();
  });

  setupEditChannel = modifier(() => {
    if (!this.args.model.post || !this.isEdit) {
      return;
    }

    const editChannel = this.presence.getChannel(
      `/discourse-presence/edit/${this.args.model.post.id}`
    );
    editChannel.subscribe();
    this.editChannel = editChannel;

    return () => editChannel.unsubscribe();
  });

  notifyState = modifier(() => {
    const { topic, post, reply } = this.args.model;
    const raw = this.isEdit ? post?.raw || "" : "";
    const entity = this.isEdit ? post : topic;

    if (reply !== raw) {
      this.composerPresenceManager.notifyState(this.state, entity?.id);
    }

    return () => this.composerPresenceManager.leave();
  });

  get isReply() {
    return this.state === "reply" || this.state === "whisper";
  }

  get isEdit() {
    return this.state === "edit";
  }

  get state() {
    if (this.args.model.editingPost) {
      return "edit";
    } else if (this.args.model.whisper) {
      return "whisper";
    } else if (this.args.model.replyingToTopic) {
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
    <div
      {{this.setupReplyChannel}}
      {{this.setupWhisperChannel}}
      {{this.setupEditChannel}}
      {{this.notifyState}}
    >
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
