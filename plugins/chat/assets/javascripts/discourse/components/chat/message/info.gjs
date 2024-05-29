import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { and } from "truth-helpers";
import BookmarkIcon from "discourse/components/bookmark-icon";
import UserStatusMessage from "discourse/components/user-status-message";
import concatClass from "discourse/helpers/concat-class";
import { prioritizeNameInUx } from "discourse/lib/settings";
import dIcon from "discourse-common/helpers/d-icon";
import { bind } from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";
import ChannelTitle from "discourse/plugins/chat/discourse/components/channel-title";
import formatChatDate from "../../../helpers/format-chat-date";

export default class ChatMessageInfo extends Component {
  @service site;
  @service siteSettings;

  @bind
  trackStatus() {
    this.#user?.statusManager.trackStatus();
  }

  @bind
  stopTrackingStatus() {
    this.#user?.statusManager.stopTrackingStatus();
  }

  get usernameClasses() {
    const user = this.#user;

    const classes = this.prioritizeName ? ["is-full-name"] : ["is-username"];
    if (!user) {
      return classes;
    }
    if (user.staff) {
      classes.push("is-staff");
    }
    if (user.admin) {
      classes.push("is-admin");
    }
    if (user.moderator) {
      classes.push("is-moderator");
    }
    if (user.new_user) {
      classes.push("is-new-user");
    }
    if (user.primary_group_name) {
      classes.push("group--" + user.primary_group_name);
    }
    return classes.join(" ");
  }

  get name() {
    return this.prioritizeName
      ? this.#user?.get("name")
      : this.#user?.get("username");
  }

  get isFlagged() {
    return (
      this.args.message?.reviewableId || this.args.message?.userFlagStatus === 0
    );
  }

  get prioritizeName() {
    return (
      this.siteSettings.display_name_on_posts &&
      prioritizeNameInUx(this.#user?.get("name"))
    );
  }

  get showStatus() {
    return !!this.#user?.get("status");
  }

  get #user() {
    return this.args.message?.user;
  }

  get routeModels() {
    if (this.site.mobileView) {
      return [...this.args.message.channel.routeModels, this.args.message.id];
    } else {
      return [
        ...this.args.message.channel.routeModels,
        this.args.message.id,
        this.args.message.thread.id,
      ];
    }
  }

  get route() {
    if (this.site.mobileView) {
      return "chat.channel.near-message";
    } else {
      return "chat.channel.near-message-with-thread";
    }
  }

  <template>
    {{#if @show}}
      <div
        class="chat-message-info"
        {{didInsert this.trackStatus}}
        {{willDestroy this.stopTrackingStatus}}
      >
        {{#if @message.chatWebhookEvent}}
          {{#if @message.chatWebhookEvent.username}}
            <span
              class={{concatClass
                "chat-message-info__username"
                this.usernameClasses
              }}
            >
              {{@message.chatWebhookEvent.username}}
            </span>
          {{/if}}

          <span class="chat-message-info__bot-indicator">
            {{i18n "chat.bot"}}
          </span>
        {{else}}
          <span
            role="button"
            class={{concatClass
              "chat-message-info__username"
              this.usernameClasses
              "clickable"
            }}
            data-user-card={{@message.user.username}}
          >
            <span class="chat-message-info__username__name">{{this.name}}</span>
            {{#if this.showStatus}}
              <span class="chat-message-info__status">
                <UserStatusMessage @status={{@message.user.status}} />
              </span>
            {{/if}}
          </span>
        {{/if}}

        <span class="chat-message-info__date">
          {{formatChatDate @message (hash threadContext=@threadContext)}}
        </span>

        {{#if @message.bookmark}}
          <span class="chat-message-info__bookmark">
            <BookmarkIcon @bookmark={{@message.bookmark}} />
          </span>
        {{/if}}

        {{#if this.isFlagged}}
          <span class="chat-message-info__flag">
            {{#if @message.reviewableId}}
              <LinkTo @route="review.show" @model={{@message.reviewableId}}>
                {{dIcon "flag" title="chat.flagged"}}
              </LinkTo>
            {{else}}
              {{dIcon "flag" title="chat.you_flagged"}}
            {{/if}}
          </span>
        {{/if}}

        {{#if (and @threadContext @message.isOriginalThreadMessage)}}
          <LinkTo
            @route={{this.route}}
            @models={{this.routeModels}}
            class="chat-message-info__original-message"
          >
            <span class="chat-message-info__original-message__text">
              {{i18n "chat.see_in"}}
            </span>
            <ChannelTitle @channel={{@message.channel}} />
          </LinkTo>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
