import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import dIcon from "discourse/helpers/d-icon";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import laterFn from "../../../modifiers/chat/later-fn";

export default class MentionWithoutMembership extends Component {
  @service("chat-api") chatApi;

  @tracked invitationsSent = false;

  get userIds() {
    return this.args.notice.data.user_ids;
  }

  @action
  async sendInvitations(event) {
    // preventDefault to avoid a refresh
    event.preventDefault();

    try {
      await this.chatApi.invite(this.args.channel.id, this.userIds, {
        messageId: this.args.notice.data.messageId,
      });

      this.invitationsSent = true;
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <div class="mention-without-membership-notice">
      {{#if this.invitationsSent}}
        <span
          class="mention-without-membership-notice__invitation-sent"
          {{laterFn @clearNotice 3000}}
        >
          {{dIcon "check"}}
          <span>
            {{i18n
              "chat.mention_warning.invitations_sent"
              count=this.userIds.length
            }}
          </span>
        </span>
      {{else}}
        <p class="mention-without-membership-notice__body -without-membership">
          <span
            class="mention-without-membership-notice__body__text"
          >{{@notice.data.text}}</span>
          <a
            class="mention-without-membership-notice__body__link"
            href
            {{on "click" this.sendInvitations}}
          >
            {{i18n "chat.mention_warning.invite"}}
          </a>
        </p>
      {{/if}}
    </div>
  </template>
}
