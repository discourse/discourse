import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import { gt } from "truth-helpers";
import UserLink from "discourse/components/user-link";
import avatar from "discourse/helpers/avatar";
import i18n from "discourse-common/helpers/i18n";

export default class TopicPresenceDisplay extends Component {
  @service presence;
  @service currentUser;

  @tracked replyChannel;
  @tracked whisperChannel;

  setupReplyChannel = modifier(() => {
    const replyChannel = this.presence.getChannel(this.replyChannelName);
    replyChannel.subscribe();
    this.replyChannel = replyChannel;

    return () => {
      replyChannel.unsubscribe();
    };
  });

  setupWhisperChannels = modifier(() => {
    if (!this.currentUser.staff) {
      return;
    }

    const whisperChannel = (this.whisperChannel = this.presence.getChannel(
      this.whisperChannelName
    ));
    whisperChannel.subscribe();
    this.whisperChannel = whisperChannel;

    return () => {
      whisperChannel.unsubscribe();
    };
  });

  get replyChannelName() {
    return `/discourse-presence/reply/${this.args.topic.id}`;
  }

  get whisperChannelName() {
    return `/discourse-presence/whisper/${this.args.topic.id}`;
  }

  get users() {
    const replyUsers = this.replyChannel?.get("users") || [];
    const whisperUsers = this.whisperChannel?.get("users") || [];

    return [...replyUsers, ...whisperUsers].filter(
      (u) => u.id !== this.currentUser.id
    );
  }

  <template>
    <div {{this.setupReplyChannel}} {{this.setupWhisperChannels}}>
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
              {{i18n "presence.replying_to_topic" count=this.users.length}}
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
