import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import BookmarkIcon from "discourse/components/bookmark-icon";
import { bind } from "discourse/lib/decorators";
import { prioritizeNameInUx } from "discourse/lib/settings";
import { and, eq, not } from "discourse/truth-helpers";
import DUserStatusMessage from "discourse/ui-kit/d-user-status-message";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import ChannelTitle from "discourse/plugins/chat/discourse/components/channel-title";
import formatChatDate from "../../../helpers/format-chat-date";

export default class ChatMessageInfo extends Component {
  @service site;
  @service siteSettings;

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

  get interactive() {
    return this.args.interactive !== false;
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

  @bind
  trackStatus() {
    this.#user?.statusManager.trackStatus();
  }

  @bind
  stopTrackingStatus() {
    this.#user?.statusManager.stopTrackingStatus();
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
              class={{dConcatClass
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
          {{! The name carries the click target rather than the wrapper: a status message
          brings its own tooltip trigger, which cannot sit inside a button. }}
          <span
            class={{dConcatClass
              "chat-message-info__username"
              this.usernameClasses
              (if this.interactive "clickable")
            }}
          >
            {{#if this.interactive}}
              <button
                class="chat-message-info__username__name"
                data-user-card={{@message.user.username}}
                type="button"
              >{{this.name}}</button>
            {{else}}
              <span
                class="chat-message-info__username__name"
              >{{this.name}}</span>
            {{/if}}
            {{#if this.showStatus}}
              <span class="chat-message-info__status">
                <DUserStatusMessage @status={{@message.user.status}} />
              </span>
            {{/if}}
          </span>
        {{/if}}

        <span class="chat-message-info__date">
          {{formatChatDate
            @message
            (hash threadContext=@threadContext mode=@dateMode)
          }}
        </span>

        {{#if @message.bookmark}}
          <span class="chat-message-info__bookmark">
            <BookmarkIcon @bookmark={{@message.bookmark}} />
          </span>
        {{/if}}

        {{#if this.siteSettings.chat_pinned_messages}}
          {{#if (and @message.pinned (not (eq @context "pinned")))}}
            <span
              class="chat-message-info__pinned"
              title={{i18n "chat.pinned"}}
            >
              {{dIcon "thumbtack"}}
            </span>
          {{/if}}
        {{/if}}

        {{#if this.isFlagged}}
          <span class="chat-message-info__flag">
            {{#if @message.reviewableId}}
              <LinkTo @model={{@message.reviewableId}} @route="review.show">
                {{dIcon "flag" title="chat.flagged"}}
              </LinkTo>
            {{else}}
              {{dIcon "flag" title="chat.you_flagged"}}
            {{/if}}
          </span>
        {{/if}}

        {{#if (and @threadContext @message.isOriginalThreadMessage)}}
          <LinkTo
            class="chat-message-info__original-message"
            @models={{this.routeModels}}
            @route={{this.route}}
          >
            <span class="chat-message-info__original-message__text">
              {{i18n "chat.see_in"}}
            </span>
            <ChannelTitle @channel={{@message.channel}} />
          </LinkTo>
        {{/if}}
      </div>
    {{else if
      (and this.interactive @message.user.username (not @message.isAction))
    }}
      {{! A message chained to the one above shows no author, but it still has one. Keeping
      the name rendered keeps the transcript attributable when it is being read rather than
      seen, and gives the message a control the keyboard can reach. An action message is
      excluded: it names its author in its own text. }}
      <div class="chat-message-info -author-only sr-only">
        <button
          class="chat-message-info__username__name"
          data-user-card={{@message.user.username}}
          type="button"
        >{{this.name}}</button>
      </div>
    {{/if}}
  </template>
}
