import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import { gt } from "truth-helpers";
import UserLink from "discourse/components/user-link";
import avatar from "discourse/helpers/avatar";
import i18n from "discourse-common/helpers/i18n";

export default class TopicPresenceDisplayComponent extends Component {
  @service presence;
  @service currentUser;

  @tracked replyChannel;
  @tracked whisperChannel;

  setupChannels = modifier(() => {
    if (this.replyChannel?.name !== this.replyChannelName) {
      this.replyChannel = this.presence.getChannel(this.replyChannelName);
      this.replyChannel.subscribe();
    }

    if (
      this.currentUser.staff &&
      this.whisperChannel?.name !== this.whisperChannelName
    ) {
      this.whisperChannel = this.presence.getChannel(this.whisperChannelName);
      this.whisperChannel.subscribe();
    }

    return () => {
      this.replyChannel?.unsubscribe();
      this.whisperChannel?.unsubscribe();
    };
  });

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
