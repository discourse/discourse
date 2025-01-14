import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { isEmpty } from "@ember/utils";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseLater from "discourse/lib/later";
import { i18n } from "discourse-i18n";
import {
  EXISTING_TOPIC_SELECTION,
  NEW_TOPIC_SELECTION,
} from "discourse/plugins/chat/discourse/components/chat-to-topic-selector";
import { CHANNEL_STATUSES } from "discourse/plugins/chat/discourse/models/chat-channel";
import ChatToTopicSelector from "../../chat-to-topic-selector";

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
    labels[NEW_TOPIC_SELECTION] = i18n(
      "chat.selection.new_topic.instructions_channel_archive"
    );
    labels[EXISTING_TOPIC_SELECTION] = i18n(
      "chat.selection.existing_topic.instructions_channel_archive"
    );
    return labels;
  }

  get instructionsText() {
    return htmlSafe(
      i18n("chat.channel_archive.instructions", {
        channelTitle: this.channel.escapedTitle,
      })
    );
  }

  get data() {
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

  @action
  archiveChannel() {
    this.saving = true;

    return this.chatApi
      .createChannelArchive(this.channel.id, this.data)
      .then(() => {
        this.flash = i18n("chat.channel_archive.process_started");
        this.flashType = "success";
        this.channel.status = CHANNEL_STATUSES.archived;

        discourseLater(() => {
          this.args.closeModal();
        }, 3000);
      })
      .catch(popupAjaxError)
      .finally(() => (this.saving = false));
  }

  @action
  newTopicSelected(topic) {
    this.selectedTopicId = topic.id;
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      class="chat-modal-archive-channel"
      @inline={{@inline}}
      @title={{i18n "chat.channel_archive.title"}}
      @flash={{this.flash}}
      @flashType={{this.flashType}}
    >
      <:body>
        <p class="chat-modal-archive-channel__instructions">
          {{this.instructionsText}}
        </p>
        <ChatToTopicSelector
          @selection={{this.selection}}
          @topicTitle={{this.topicTitle}}
          @categoryId={{this.categoryId}}
          @tags={{this.tags}}
          @topicChangedCallback={{this.newTopicSelected}}
          @instructionLabels={{this.instructionLabels}}
          @allowNewMessage={{false}}
        />
      </:body>
      <:footer>
        <DButton
          @disabled={{this.buttonDisabled}}
          @action={{this.archiveChannel}}
          @label="chat.channel_archive.title"
          id="chat-confirm-archive-channel"
          class="btn-primary"
        />
      </:footer>
    </DModal>
  </template>
}
