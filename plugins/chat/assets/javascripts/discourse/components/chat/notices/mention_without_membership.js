import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";

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
}
