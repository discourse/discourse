import Component from "@glimmer/component";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { inject as service } from "@ember/service";

export default class ChatRetentionReminder extends Component {
  @service currentUser;

  get show() {
    return (
      !this.args.channel?.isDraft &&
      ((this.args.channel?.isDirectMessageChannel &&
        this.currentUser?.needs_dm_retention_reminder) ||
        (this.args.channel?.isCategoryChannel &&
          this.currentUser?.needs_channel_retention_reminder))
    );
  }

  @action
  dismiss() {
    return ajax("/chat/dismiss-retention-reminder", {
      method: "POST",
      data: { chatable_type: this.args.channel.chatableType },
    })
      .then(() => {
        const field = this.args.channel.isDirectMessageChannel
          ? "needs_dm_retention_reminder"
          : "needs_channel_retention_reminder";
        this.currentUser.set(field, false);
      })
      .catch(popupAjaxError);
  }
}
