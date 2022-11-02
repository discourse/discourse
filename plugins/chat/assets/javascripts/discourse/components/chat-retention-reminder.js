import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";
import I18n from "I18n";
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
        (!this.chatChannel.isDirectMessageChannel &&
          this.currentUser.needs_channel_retention_reminder))
    );
  },

  @discourseComputed("chatChannel.chatable_type")
  text() {
    let days = this.siteSettings.chat_channel_retention_days;
    let translationKey = "chat.retention_reminders.public";

    if (this.chatChannel.isDirectMessageChannel) {
      days = this.siteSettings.chat_dm_retention_days;
      translationKey = "chat.retention_reminders.dm";
    }
    return I18n.t(translationKey, { days });
  },

  @discourseComputed("chatChannel.chatable_type")
  daysCount() {
    return this.chatChannel.isDirectMessageChannel
      ? this.siteSettings.chat_dm_retention_days
      : this.siteSettings.chat_channel_retention_days;
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
