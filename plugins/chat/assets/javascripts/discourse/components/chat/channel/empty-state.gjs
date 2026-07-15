import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import DEmptyState from "discourse/ui-kit/d-empty-state";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const MAX_AVATARS = 5;

export default class ChatChannelEmptyState extends Component {
  @service chatApi;
  @service currentUser;

  constructor() {
    super(...arguments);

    // Anonymous users can't list memberships, so skip the fetch and fall back
    // to the count-only display for them.
    if (this.currentUser) {
      this.memberships.load({ limit: MAX_AVATARS }).catch(() => {
        // A failed preview fetch degrades to count-only; not worth interrupting.
      });
    }
  }

  @cached
  get memberships() {
    return this.chatApi.listChannelMemberships(this.args.channel.id);
  }

  get title() {
    return i18n("chat.channel.empty_state.title", {
      channelName: `#${this.args.channel.title}`,
    });
  }

  get tip() {
    if (!this.currentUser) {
      return i18n("chat.channel.empty_state.guest_tip");
    }

    return null;
  }

  <template>
    <DEmptyState
      @identifier="chat-channel"
      @svgContent={{dIcon "comments"}}
      @title={{this.title}}
      @body={{@channel.description}}
    >
      <:tip>
        {{#if this.tip}}
          <p class="empty-state__tip-text">{{this.tip}}</p>
        {{/if}}

        {{#if @channel.membershipsCount}}
          <div
            class={{dConcatClass
              "empty-state__members-facepile"
              (if this.memberships.items.length "--with-avatars")
            }}
          >
            {{#if this.memberships.items.length}}
              <div class="empty-state__members-avatars">
                {{#each this.memberships.items as |membership|}}
                  {{dAvatar membership.user imageSize="small"}}
                {{/each}}
              </div>
            {{/if}}
            <span class="empty-state__members-count">
              {{trustHTML
                (i18n
                  "chat.channel.empty_state.members_here"
                  count=@channel.membershipsCount
                )
              }}
            </span>
          </div>
        {{/if}}
      </:tip>
    </DEmptyState>
  </template>
}
