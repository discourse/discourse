import Component from "@glimmer/component";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import i18n from "discourse-common/helpers/i18n";
import htmlSafe from "discourse-common/helpers/html-safe";

import { tracked } from "@glimmer/tracking";
import { getOwner } from "@ember/application";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { Promise } from "rsvp";
import Topic from "discourse/models/topic";
import AppendTags from "../bulk-actions/append-tags";
import ChangeCategory from "../bulk-actions/change-category";
import ChangeTags from "../bulk-actions/change-tags";
import NotificationLevel from "../bulk-actions/notification-level";

export default class BulkTopicActions extends Component {
  @service router;

  async perform(operation) {
    this.loading = true;

    if (this.args.model.topics.length > 20) {
      this.showProgress = true;
    }

    try {
      return this._processChunks(operation);
    } catch {
      this.dialog.alert(I18n.t("generic_error"));
    } finally {
      this.loading = false;
      this.processedTopicCount = 0;
      this.showProgress = false;
    }
  }

  _generateTopicChunks(allTopics) {
    let startIndex = 0;
    const chunkSize = 30;
    const chunks = [];

    while (startIndex < allTopics.length) {
      const topics = allTopics.slice(startIndex, startIndex + chunkSize);
      chunks.push(topics);
      startIndex += chunkSize;
    }

    return chunks;
  }

  _processChunks(operation) {
    const allTopics = this.args.model.topics;
    const topicChunks = this._generateTopicChunks(allTopics);
    const topicIds = [];

    const tasks = topicChunks.map((topics) => async () => {
      const result = await Topic.bulkOperation(topics, operation);
      this.processedTopicCount = this.processedTopicCount + topics.length;
      return result;
    });

    return new Promise((resolve, reject) => {
      const resolveNextTask = async () => {
        if (tasks.length === 0) {
          const topics = topicIds.map((id) => allTopics.findBy("id", id));
          return resolve(topics);
        }

        const task = tasks.shift();

        try {
          const result = await task();
          if (result?.topic_ids) {
            topicIds.push(...result.topic_ids);
          }
          resolveNextTask();
        } catch {
          reject();
        }
      };

      resolveNextTask();
    });
  }

  @action
  setComponent(component) {
    this.activeComponent = component;
  }

  @action
  performAction() {
    // TODO: return only visible topics
    //visible: ({ topics }) => !topics.some((t) => t.isPrivateMessage),
    const t = this.args.model.topics;

    switch (this.args.model.action) {
      case "close":
        this.forEachPerformed({ type: "close" }, (t) => t.set("closed", true));
        break;
    }
  }

  @action
  async forEachPerformed(operation, cb) {
    const topics = await this.perform(operation);

    if (topics) {
      topics.forEach(cb);
      this.args.model.refreshClosure?.();
      this.args.closeModal();

      //this.router.refresh();
      // refresh wasn't updating the topic list, so just using
      // reload for now.
      window.location.reload();
    }
  }

  @action
  async performAndRefresh(operation) {
    await this.perform(operation);

    this.args.model.refreshClosure?.();
    this.args.closeModal();
  }

  <template>
    <DModal
      @title={{@model.title}}
      @closeModal={{@closeModal}}
      class="topic-bulk-actions-modal -large"
    >
      <:body>
        <div>
          {{htmlSafe (i18n "topics.bulk.selected" count=@model.topics.length)}}
        </div>
        <div>body</div>
      </:body>

      <:footer>
        {{#if @model.silent}}
          <div><input class="" id="silent" type="checkbox" />
            <label for="silent">Perform this action silently.</label>
          </div>
        {{/if}}
        <DButton
          @action={{this.performAction}}
          @icon="check"
          @label="topics.bulk.confirm"
          id="bulk-topics-confirm"
          class="btn-primary"
        />
      </:footer>

    </DModal>
  </template>
}
