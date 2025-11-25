import Component from "@glimmer/component";
import { concat, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import replaceEmoji from "discourse/helpers/replace-emoji";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { and, gt } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import ToggleChannelMembershipButton from "./toggle-channel-membership-button";

export default class ChatChannelCard extends Component {
  @service chatApi;
  @service toasts;
  @service siteSettings;

  get isStarred() {
    return this.args.channel?.currentUserMembership?.starred;
  }

  get starIcon() {
    return this.isStarred ? "star" : "far-star";
  }

  get starTitle() {
    return this.isStarred
      ? i18n("chat.channel_settings.unstar_channel")
      : i18n("chat.channel_settings.star_channel");
  }

  @action
  async toggleStarred(event) {
    event.preventDefault();
    event.stopPropagation();

    const channel = this.args.channel;
    if (!channel?.currentUserMembership) {
      return;
    }

    const newValue = !channel.currentUserMembership.starred;
    const previousValue = channel.currentUserMembership.starred;

    channel.currentUserMembership.starred = newValue;

    try {
      await this.chatApi.updateCurrentUserChannelMembership(channel.id, {
        starred: newValue,
      });
      this.toasts.success({ data: { message: i18n("saved") } });
    } catch (error) {
      channel.currentUserMembership.starred = previousValue;
      popupAjaxError(error);
    }
  }

  <template>
    {{#if @channel}}
      <div
        class={{concatClass
          "chat-channel-card"
          (if @channel.isClosed "--closed")
          (if @channel.isArchived "--archived")
        }}
        style={{htmlSafe
          (concat "--chat-channel-card-border: #" @channel.chatable.color)
        }}
        data-channel-id={{@channel.id}}
      >
        <div class="chat-channel-card__header">
          <LinkTo
            @route="chat.channel"
            @models={{@channel.routeModels}}
            class="chat-channel-card__name-container"
          >
            <span class="chat-channel-card__name">
              {{replaceEmoji @channel.title}}
            </span>
            {{#if @channel.chatable.read_restricted}}
              {{icon "lock" class="chat-channel-card__read-restricted"}}
            {{/if}}
            {{#if @channel.currentUserMembership.muted}}
              <span
                class="chat-channel-card__muted"
                aria-label={{i18n "chat.muted"}}
                title={{i18n "chat.muted"}}
              >{{icon "d-muted"}}</span>
            {{/if}}
          </LinkTo>
          {{#if
            (and
              @channel.currentUserMembership
              this.siteSettings.star_chat_channels
            )
          }}
            <DButton
              {{on "click" this.toggleStarred}}
              @icon={{this.starIcon}}
              @title={{this.starTitle}}
              class={{concatClass
                "btn-transparent"
                "chat-channel-card__star-btn"
                (if this.isStarred "--starred")
              }}
            />
          {{/if}}
        </div>

        <div class="chat-channel-card__cta">
          {{#if @channel.isFollowing}}
            <ToggleChannelMembershipButton
              @channel={{@channel}}
              @options={{hash
                leaveClass="btn-transparent btn-danger chat-channel-card__leave-btn"
                labelType="short"
              }}
            />

          {{else if @channel.isJoinable}}
            <ToggleChannelMembershipButton
              @channel={{@channel}}
              @options={{hash
                joinClass="btn-primary btn-small chat-channel-card__join-btn"
                labelType="short"
              }}
            />
          {{/if}}
        </div>

        {{#if (gt @channel.membershipsCount 0)}}
          <LinkTo
            @route="chat.channel.info.members"
            @models={{@channel.routeModels}}
            class="chat-channel-card__members"
          >
            {{i18n
              "chat.channel.memberships_count"
              count=@channel.membershipsCount
            }}
          </LinkTo>
        {{/if}}

        {{#if @channel.description}}
          <div class="chat-channel-card__description">
            {{replaceEmoji @channel.description}}
          </div>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
