import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { gt } from "truth-helpers";
import UserLink from "discourse/components/user-link";
import avatar from "discourse/helpers/avatar";
import helperFn from "discourse/helpers/helper-fn";
import { i18n } from "discourse-i18n";

export default class TopicPresenceDisplay extends Component {
  @service presence;
  @service currentUser;

  @tracked replyChannel;
  @tracked whisperChannel;

  setupReplyChannel = helperFn((_, on) => {
    const replyChannel = this.presence.getChannel(
      `/discourse-presence/reply/${this.args.topic.id}`
    );
    replyChannel.subscribe();
    this.replyChannel = replyChannel;

    on.cleanup(() => replyChannel.unsubscribe());
  });

  setupWhisperChannels = helperFn((_, on) => {
    if (!this.currentUser.staff) {
      return;
    }

    const whisperChannel = this.presence.getChannel(
      `/discourse-presence/whisper/${this.args.topic.id}`
    );
    whisperChannel.subscribe();
    this.whisperChannel = whisperChannel;

    on.cleanup(() => whisperChannel.unsubscribe());
  });

  @cached
  get users() {
    const replyUsers = this.replyChannel?.users || [];
    const whisperUsers = this.whisperChannel?.users || [];

    return [...replyUsers, ...whisperUsers].filter(
      (u) => u.id !== this.currentUser.id
    );
  }

  <template>
    {{this.setupReplyChannel}}
    {{this.setupWhisperChannels}}

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
  </template>
}
