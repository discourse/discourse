import Component from "@glimmer/component";
import { action } from "@ember/object";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";

export default class MentionWithoutMembership extends Component {
  @service("chat-api") api;

  @tracked invitationsSent = false;

  get userIds() {
    return this.args.notice.componentArgs.user_ids;
  }

  @action
  async sendInvitations(event) {
    // preventDefault to avoid a refresh
    event.preventDefault();

    try {
      await this.api.invite(this.args.channel.id, this.userIds, {
        messageId: this.args.notice.componentArgs.messageId,
      });

      this.invitationsSent = true;
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  dismiss() {
    this.args.clearNotice(this.args.notice);
  }
}
