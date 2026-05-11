import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { isPresent } from "@ember/utils";
import { popupAjaxError } from "discourse/lib/ajax-error";
import getURL from "discourse/lib/get-url";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

export default class ChatChannelArchiveStatus extends Component {
  @service chatApi;
  @service currentUser;

  get shouldRender() {
    return this.currentUser.admin && isPresent(this.args.channel.archive);
  }

  get channelArchiveFailedMessage() {
    const archive = this.args.channel.archive;
    const translationKey = !archive.topicId
      ? "chat.channel_status.archive_failed_no_topic"
      : "chat.channel_status.archive_failed";
    return trustHTML(
      i18n(translationKey, {
        completed: archive.messages,
        total: archive.totalMessages,
        topic_url: this.topicUrl,
      })
    );
  }

  get channelArchiveCompletedMessage() {
    return trustHTML(
      i18n("chat.channel_status.archive_completed", {
        topic_url: this.topicUrl,
      })
    );
  }

  @action
  retryArchive() {
    return this.chatApi
      .createChannelArchive(this.args.channel.id)
      .catch(popupAjaxError);
  }

  get topicUrl() {
    if (!this.args.channel.archive.topicId) {
      return "";
    }
    return getURL(`/t/-/${this.args.channel.archive.topicId}`);
  }

  <template>
    {{#if this.shouldRender}}
      {{#if @channel.archive.failed}}
        <div
          class={{dConcatClass
            "alert alert-warn chat-channel-retry-archive"
            @channel.status
          }}
        >
          <div class="chat-channel-archive-failed-message">
            {{this.channelArchiveFailedMessage}}
          </div>

          <div class="chat-channel-archive-failed-retry">
            <DButton
              @action={{this.retryArchive}}
              @label="chat.channel_archive.retry"
            />
          </div>
        </div>
      {{else if @channel.archive.completed}}
        <div
          class={{dConcatClass "chat-channel-archive-status" @channel.status}}
        >
          {{this.channelArchiveCompletedMessage}}
        </div>
      {{/if}}
    {{/if}}
  </template>
}
