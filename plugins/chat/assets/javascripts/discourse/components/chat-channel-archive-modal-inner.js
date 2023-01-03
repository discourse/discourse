import Component from "@ember/component";
import I18n from "I18n";
import discourseLater from "discourse-common/lib/later";
import { isEmpty } from "@ember/utils";
import discourseComputed from "discourse-common/utils/decorators";
import { action } from "@ember/object";
import { equal } from "@ember/object/computed";
import { inject as service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import {
  EXISTING_TOPIC_SELECTION,
  NEW_TOPIC_SELECTION,
} from "discourse/plugins/chat/discourse/components/chat-to-topic-selector";
import { CHANNEL_STATUSES } from "discourse/plugins/chat/discourse/models/chat-channel";
import { htmlSafe } from "@ember/template";
import ModalFunctionality from "discourse/mixins/modal-functionality";

export default Component.extend(ModalFunctionality, {
  chat: service(),
  chatApi: service(),
  tagName: "",
  chatChannel: null,

  selection: NEW_TOPIC_SELECTION,
  newTopic: equal("selection", NEW_TOPIC_SELECTION),
  existingTopic: equal("selection", EXISTING_TOPIC_SELECTION),

  saving: false,

  topicTitle: null,
  categoryId: null,
  tags: null,
  selectedTopicId: null,

  @action
  archiveChannel() {
    this.set("saving", true);

    return this.chatApi
      .createChannelArchive(this.chatChannel.id, this._data())
      .then(() => {
        this.flash(I18n.t("chat.channel_archive.process_started"), "success");
        this.chatChannel.set("status", CHANNEL_STATUSES.archived);

        discourseLater(() => {
          this.closeModal();
        }, 3000);
      })
      .catch(popupAjaxError)
      .finally(() => this.set("saving", false));
  },

  _data() {
    const data = {
      type: this.selection,
    };
    if (this.newTopic) {
      data.title = this.topicTitle;
      data.category_id = this.categoryId;
      data.tags = this.tags;
    }
    if (this.existingTopic) {
      data.topic_id = this.selectedTopicId;
    }
    return data;
  },

  @discourseComputed("saving", "selectedTopicId", "topicTitle", "selection")
  buttonDisabled(saving, selectedTopicId, topicTitle) {
    if (saving) {
      return true;
    }
    if (
      this.newTopic &&
      (!topicTitle ||
        topicTitle.length < this.siteSettings.min_topic_title_length ||
        topicTitle.length > this.siteSettings.max_topic_title_length)
    ) {
      return true;
    }

    if (this.existingTopic && isEmpty(selectedTopicId)) {
      return true;
    }
    return false;
  },

  @discourseComputed()
  instructionLabels() {
    const labels = {};
    labels[NEW_TOPIC_SELECTION] = I18n.t(
      "chat.selection.new_topic.instructions_channel_archive"
    );
    labels[EXISTING_TOPIC_SELECTION] = I18n.t(
      "chat.selection.existing_topic.instructions_channel_archive"
    );
    return labels;
  },

  @discourseComputed()
  instructionsText() {
    return htmlSafe(
      I18n.t("chat.channel_archive.instructions", {
        channelTitle: this.chatChannel.escapedTitle,
      })
    );
  },
});
