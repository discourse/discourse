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

  setupChannels = modifier(() => {
    const topic = this.args.model.get("topic");
    const post = this.args.model.get("post");
    const reply = this.args.model.get("reply");
    let replyChannel;
    let whisperChannel;
    let editChannel;

    if (topic && this.isReply) {
      replyChannel = this.presence.getChannel(
        `/discourse-presence/reply/${topic.id}`
      );
      replyChannel.subscribe();
      this.replyChannel = replyChannel;

      if (this.currentUser.staff && this.currentUser.get("whisperer")) {
        whisperChannel = this.presence.getChannel(
          `/discourse-presence/whisper/${topic.id}`
        );
        whisperChannel.subscribe();
        this.whisperChannel = whisperChannel;
      }
    }

    if (post && this.isEdit) {
      editChannel = this.presence.getChannel(
        `/discourse-presence/edit/${post.id}`
      );
      editChannel.subscribe();
      this.editChannel = editChannel;
    }

    const raw = this.isEdit ? post?.raw || "" : "";
    const entity = this.isEdit ? post : topic;

    if (reply !== raw) {
      this.composerPresenceManager.notifyState(this.state, entity?.id);
    }

    return () => {
      replyChannel?.unsubscribe();
      whisperChannel?.unsubscribe();
      editChannel?.unsubscribe();
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
    if (this.args.model.get("editingPost")) {
      return "edit";
    } else if (this.args.model.get("whisper")) {
      return "whisper";
    } else if (this.args.model.get("replyingToTopic")) {
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
