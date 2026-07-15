import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import DEmptyState from "discourse/ui-kit/d-empty-state";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";
import { i18n } from "discourse-i18n";

const MAX_AVATARS = 5;

export default class ChatChannelEmptyState extends Component {
  @service chatApi;
  @service currentUser;

  @cached
  get memberships() {
    return this.chatApi.listChannelMemberships(this.args.channel.id);
  }

  @action
  loadMemberships() {
    // Anonymous users can't list memberships, so skip the fetch and fall back
    // to the count-only display for them.
    if (!this.currentUser) {
      return;
    }

    this.memberships.load({ limit: MAX_AVATARS }).catch(() => {});
  }

  get otherMemberships() {
    return this.memberships.items.filter(
      (membership) => membership.user.id !== this.currentUser?.id
    );
  }

  get memberCount() {
    const count = this.args.channel.membershipsCount;
    return this.args.channel.isFollowing ? count - 1 : count;
  }

  get channelIcon() {
    const { emoji, chatable } = this.args.channel;
    const icon = emoji ? dReplaceEmoji(`:${emoji}:`) : dIcon("d-chat");

    if (!chatable?.color) {
      return icon;
    }

    return trustHTML(`<span style="color: #${chatable.color}">${icon}</span>`);
  }

  get title() {
    const channelName = `#${this.args.channel.title}`;

    if (this.args.channel.isFollowing) {
      return i18n("chat.channel.empty_state.joined_title", { channelName });
    }

    return i18n("chat.channel.empty_state.title", { channelName });
  }

  get tip() {
    if (this.args.channel.isFollowing) {
      return i18n("chat.channel.empty_state.joined_tip");
    }

    return i18n("chat.channel.empty_state.guest_tip");
  }

  <template>
    {{#if this.currentUser}}
      <DEmptyState
        @identifier="chat-channel"
        @svgContent={{this.channelIcon}}
        @title={{this.title}}
        @body={{@channel.description}}
      >
        <:tip>
          {{#if this.tip}}
            <p class="empty-state__tip-text">{{this.tip}}</p>
          {{/if}}

          <div
            class={{dConcatClass
              "empty-state__members-facepile"
              (if this.otherMemberships.length "--with-avatars")
            }}
            {{didInsert this.loadMemberships}}
          >
            {{#if this.otherMemberships.length}}
              <div class="empty-state__members-avatars">
                {{#each this.otherMemberships as |membership|}}
                  {{dAvatar membership.user imageSize="small"}}
                {{/each}}
              </div>
            {{/if}}
            <span class="empty-state__members-count">
              {{#if this.memberCount}}
                {{trustHTML
                  (i18n
                    "chat.channel.empty_state.members_here"
                    count=this.memberCount
                  )
                }}
              {{else}}
                {{i18n "chat.channel.empty_state.no_other_members"}}
              {{/if}}
            </span>
          </div>
        </:tip>
      </DEmptyState>
    {{/if}}
    {{#unless this.currentUser}}
      <DEmptyState
        @identifier="chat-channel"
        @svgContent={{this.channelIcon}}
        @title={{this.title}}
        @body={{@channel.description}}
      >
        <:tip>
          {{#if this.tip}}
            <p class="empty-state__tip-text">{{this.tip}}</p>
          {{/if}}
          <div class="empty-state__members-facepile">
            <span class="empty-state__members-count">
              {{#if this.memberCount}}
                {{trustHTML
                  (i18n
                    "chat.channel.empty_state.members_here"
                    count=this.memberCount
                  )
                }}
              {{else}}
                {{i18n "chat.channel.empty_state.no_other_members"}}
              {{/if}}
            </span>
          </div>
        </:tip>
      </DEmptyState>
    {{/unless}}
  </template>
}
