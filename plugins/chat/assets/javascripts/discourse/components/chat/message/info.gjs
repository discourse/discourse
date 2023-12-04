import Component from "@glimmer/component";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { LinkTo } from "@ember/routing";
import { inject as service } from "@ember/service";
import BookmarkIcon from "discourse/components/bookmark-icon";
import UserStatusMessage from "discourse/components/user-status-message";
import concatClass from "discourse/helpers/concat-class";
import { prioritizeNameInUx } from "discourse/lib/settings";
import dIcon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import { bind } from "discourse-common/utils/decorators";
import formatChatDate from "../../../helpers/format-chat-date";

export default class ChatMessageInfo extends Component {
  @service siteSettings;

  @bind
  trackStatus() {
    this.#user?.trackStatus?.();
  }

  @bind
  stopTrackingStatus() {
    this.#user?.stopTrackingStatus?.();
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
    return this.#message?.reviewableId || this.#message?.userFlagStatus === 0;
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
    return this.#message?.user;
  }

  get #message() {
    return this.args.message;
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
              <div class="chat-message-info__status">
                <UserStatusMessage @status={{@message.user.status}} />
              </div>
            {{/if}}
          </span>
        {{/if}}

        <span class="chat-message-info__date">
          {{formatChatDate @message}}
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
      </div>
    {{/if}}
  </template>
}
