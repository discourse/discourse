import Component from "@ember/component";
import { htmlSafe } from "@ember/template";
import I18n from "I18n";
import { popupAjaxError } from "discourse/lib/ajax-error";
import getURL from "discourse-common/lib/get-url";
import { action } from "@ember/object";
import discourseComputed from "discourse-common/utils/decorators";
import { inject as service } from "@ember/service";

export default Component.extend({
  channel: null,
  tagName: "",
  chatApi: service(),

  @discourseComputed(
    "channel.status",
    "channel.archived_messages",
    "channel.total_messages",
    "channel.archive_failed"
  )
  channelArchiveFailedMessage() {
    const translationKey = !this.channel.archive_topic_id
      ? "chat.channel_status.archive_failed_no_topic"
      : "chat.channel_status.archive_failed";
    return htmlSafe(
      I18n.t(translationKey, {
        completed: this.channel.archived_messages,
        total: this.channel.total_messages,
        topic_url: this._getTopicUrl(),
      })
    );
  },

  @discourseComputed(
    "channel.status",
    "channel.archived_messages",
    "channel.total_messages",
    "channel.archive_completed"
  )
  channelArchiveCompletedMessage() {
    return htmlSafe(
      I18n.t("chat.channel_status.archive_completed", {
        topic_url: this._getTopicUrl(),
      })
    );
  },

  @action
  retryArchive() {
    return this.chatApi
      .createChannelArchive(this.channel.id)
      .catch(popupAjaxError);
  },

  _getTopicUrl() {
    if (!this.channel.archive_topic_id) {
      return "";
    }
    return getURL(`/t/-/${this.channel.archive_topic_id}`);
  },
});
