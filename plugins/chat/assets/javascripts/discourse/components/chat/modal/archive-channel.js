import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { htmlSafe } from "@ember/template";
import I18n from "I18n";
import discourseLater from "discourse-common/lib/later";
import {
  EXISTING_TOPIC_SELECTION,
  NEW_TOPIC_SELECTION,
} from "discourse/plugins/chat/discourse/components/chat-to-topic-selector";
import { CHANNEL_STATUSES } from "discourse/plugins/chat/discourse/models/chat-channel";
import { isEmpty } from "@ember/utils";

export default class ChatModalArchiveChannel extends Component {
  @service chatApi;
  @service siteSettings;

  @tracked selection = NEW_TOPIC_SELECTION;
  @tracked saving = false;
  @tracked topicTitle = null;
  @tracked categoryId = null;
  @tracked tags = null;
  @tracked selectedTopicId = null;
  @tracked flash;
  @tracked flashType;

  get channel() {
    return this.args.model.channel;
  }

  get newTopic() {
    return this.selection === NEW_TOPIC_SELECTION;
  }

  get existingTopic() {
    return this.selection === EXISTING_TOPIC_SELECTION;
  }

  get buttonDisabled() {
    if (this.saving) {
      return true;
    }

    if (
      this.newTopic &&
      (!this.topicTitle ||
        this.topicTitle.length < this.siteSettings.min_topic_title_length ||
        this.topicTitle.length > this.siteSettings.max_topic_title_length)
    ) {
      return true;
    }

    if (this.existingTopic && isEmpty(this.selectedTopicId)) {
      return true;
    }

    return false;
  }

  get instructionLabels() {
    const labels = {};
    labels[NEW_TOPIC_SELECTION] = I18n.t(
      "chat.selection.new_topic.instructions_channel_archive"
    );
    labels[EXISTING_TOPIC_SELECTION] = I18n.t(
      "chat.selection.existing_topic.instructions_channel_archive"
    );
    return labels;
  }

  get instructionsText() {
    return htmlSafe(
      I18n.t("chat.channel_archive.instructions", {
        channelTitle: this.channel.escapedTitle,
      })
    );
  }

  @action
  archiveChannel() {
    this.saving = true;

    return this.chatApi
      .createChannelArchive(this.channel.id, this.#data())
      .then(() => {
        this.flash = I18n.t("chat.channel_archive.process_started");
        this.flashType = "success";
        this.channel.status = CHANNEL_STATUSES.archived;

        discourseLater(() => {
          this.args.closeModal();
        }, 3000);
      })
      .catch(popupAjaxError)
      .finally(() => (this.saving = false));
  }

  #data() {
    const data = { type: this.selection };
    if (this.newTopic) {
      data.title = this.topicTitle;
      data.category_id = this.categoryId;
      data.tags = this.tags;
    }
    if (this.existingTopic) {
      data.topic_id = this.selectedTopicId;
    }
    return data;
  }
}
