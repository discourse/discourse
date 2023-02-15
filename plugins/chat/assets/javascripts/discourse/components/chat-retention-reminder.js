import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Component.extend({
  tagName: "",
  loading: false,

  @discourseComputed(
    "chatChannel.chatable_type",
    "currentUser.{needs_dm_retention_reminder,needs_channel_retention_reminder}"
  )
  show() {
    return (
      !this.chatChannel.isDraft &&
      ((this.chatChannel.isDirectMessageChannel &&
        this.currentUser.needs_dm_retention_reminder) ||
        (this.chatChannel.isCategoryChannel &&
          this.currentUser.needs_channel_retention_reminder))
    );
  },

  @action
  dismiss() {
    return ajax("/chat/dismiss-retention-reminder", {
      method: "POST",
      data: { chatable_type: this.chatChannel.chatable_type },
    })
      .then(() => {
        const field = this.chatChannel.isDirectMessageChannel
          ? "needs_dm_retention_reminder"
          : "needs_channel_retention_reminder";
        this.currentUser.set(field, false);
      })
      .catch(popupAjaxError);
  },
});
