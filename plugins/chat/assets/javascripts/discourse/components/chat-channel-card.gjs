import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import { inject as service } from "@ember/service";
import borderColor from "discourse/helpers/border-color";
import concatClass from "discourse/helpers/concat-class";
import replaceEmoji from "discourse/helpers/replace-emoji";
import dIcon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import gt from "truth-helpers/helpers/gt";
import ToggleChannelMembershipButton from "./toggle-channel-membership-button";

export default class ChatChannelCard extends Component {
  @service chat;

  <template>
    {{#if @channel}}
      <div
        class={{concatClass
          "chat-channel-card"
          (if @channel.isClosed "-closed")
          (if @channel.isArchived "-archived")
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
          </LinkTo>

          <div class="chat-channel-card__header-actions">
            {{#if @channel.currentUserMembership.muted}}
              <LinkTo
                @route="chat.channel.info.settings"
                @models={{@channel.routeModels}}
                class="chat-channel-card__tag -muted"
                tabindex="-1"
              >
                {{i18n "chat.muted"}}
              </LinkTo>
            {{/if}}

            <LinkTo
              @route="chat.channel.info.settings"
              @models={{@channel.routeModels}}
              class="chat-channel-card__setting"
              tabindex="-1"
            >
              {{dIcon "cog"}}
            </LinkTo>
          </div>
        </div>

        {{#if @channel.description}}
          <div class="chat-channel-card__description">
            {{replaceEmoji @channel.description}}
          </div>
        {{/if}}

        <div class="chat-channel-card__cta">
          {{#if @channel.isFollowing}}
            <div class="chat-channel-card__tags">
              <span class="chat-channel-card__tag -joined">
                {{i18n "chat.joined"}}
              </span>

              <ToggleChannelMembershipButton
                @channel={{@channel}}
                @options={{hash
                  leaveClass="btn-link btn-small chat-channel-card__leave-btn"
                  labelType="short"
                }}
              />
            </div>
          {{else if @channel.isJoinable}}
            <ToggleChannelMembershipButton
              @channel={{@channel}}
              @options={{hash
                joinClass="btn-primary btn-small chat-channel-card__join-btn"
                labelType="short"
              }}
            />
          {{/if}}

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
        </div>
      </div>
    {{/if}}
  </template>
}
