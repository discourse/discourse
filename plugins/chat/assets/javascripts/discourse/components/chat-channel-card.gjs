import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { gt } from "truth-helpers";
import borderColor from "discourse/helpers/border-color";
import concatClass from "discourse/helpers/concat-class";
import dIcon from "discourse/helpers/d-icon";
import replaceEmoji from "discourse/helpers/replace-emoji";
import { i18n } from "discourse-i18n";
import ToggleChannelMembershipButton from "./toggle-channel-membership-button";

export default class ChatChannelCard extends Component {
  @service chat;

  <template>
    {{#if @channel}}
      <div
        class={{concatClass
          "chat-channel-card"
          (if @channel.isClosed "--closed")
          (if @channel.isArchived "--archived")
        }}
        style={{borderColor @channel.chatable.color}}
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
              {{dIcon "lock" class="chat-channel-card__read-restricted"}}
            {{/if}}
            {{#if @channel.currentUserMembership.muted}}
              <span
                class="chat-channel-card__muted"
                aria-label={{i18n "chat.muted"}}
                title={{i18n "chat.muted"}}
              >{{dIcon "d-muted"}}</span>
            {{/if}}
          </LinkTo>

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
            tabindex="-1"
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
