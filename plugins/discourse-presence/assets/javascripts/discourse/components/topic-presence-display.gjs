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
    const { topic } = this.args;

    if (!topic) {
      return;
    }

    const name = `/discourse-presence/reply/${topic.id}`;
    const replyChannel = this.presence.getChannel(name);
    this.replyChannel = replyChannel;

    replyChannel.subscribe();
    on.cleanup(() => replyChannel.unsubscribe());
  });

  setupWhisperChannel = helperFn((_, on) => {
    const { topic } = this.args;
    const { whisperer } = this.currentUser;

    if (!topic || !whisperer) {
      return;
    }

    const name = `/discourse-presence/whisper/${topic.id}`;
    const whisperChannel = this.presence.getChannel(name);
    this.whisperChannel = whisperChannel;

    whisperChannel.subscribe();
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
    {{#if this.currentUser}}
      {{this.setupReplyChannel}}
      {{this.setupWhisperChannel}}

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
    {{/if}}
  </template>
}
