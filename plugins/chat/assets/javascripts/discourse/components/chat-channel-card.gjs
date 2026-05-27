import { concat, hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import { trustHTML } from "@ember/template";
import { gt } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";
import { i18n } from "discourse-i18n";
import ToggleChannelMembershipButton from "./toggle-channel-membership-button";

<template>
  {{#if @channel}}
    <div
      class={{dConcatClass
        "chat-channel-card"
        (if @channel.isClosed "--closed")
        (if @channel.isArchived "--archived")
      }}
      style={{trustHTML
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
            {{dReplaceEmoji @channel.title}}
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
              leaveClass="btn-transparent --danger chat-channel-card__leave-btn"
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
          {{dReplaceEmoji @channel.description}}
        </div>
      {{/if}}
    </div>
  {{/if}}
</template>
