import Component from "@ember/component";
import { htmlSafe } from "@ember/template";
import I18n from "I18n";
import { popupAjaxError } from "discourse/lib/ajax-error";
import getURL from "discourse-common/lib/get-url";
import { action } from "@ember/object";
import discourseComputed, { bind } from "discourse-common/utils/decorators";
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
    return htmlSafe(
      I18n.t("chat.channel_status.archive_failed", {
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

  didInsertElement() {
    this._super(...arguments);

    if (this.currentUser.admin) {
      this.messageBus.subscribe(
        "/chat/channel-archive-status",
        this.onMessage,
        this.channel.meta.message_bus_last_ids.archive_status
      );
    }
  },

  willDestroyElement() {
    this._super(...arguments);

    if (this.currentUser.admin) {
      this.messageBus.unsubscribe(
        "/chat/channel-archive-status",
        this.onMessage
      );
    }
  },

  _getTopicUrl() {
    return getURL(`/t/-/${this.channel.archive_topic_id}`);
  },

  @bind
  onMessage(busData) {
    if (busData.chat_channel_id === this.channel.id) {
      this.channel.setProperties({
        archive_failed: busData.archive_failed,
        archive_completed: busData.archive_completed,
        archived_messages: busData.archived_messages,
        archive_topic_id: busData.archive_topic_id,
        total_messages: busData.total_messages,
      });
    }
  },
});
