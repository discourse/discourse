import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { Promise } from "rsvp";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import Topic from "discourse/models/topic";
import htmlSafe from "discourse-common/helpers/html-safe";
import i18n from "discourse-common/helpers/i18n";
//import AppendTags from "../bulk-actions/append-tags";
//import ChangeCategory from "../bulk-actions/change-category";
//import ChangeTags from "../bulk-actions/change-tags";
//import NotificationLevel from "../bulk-actions/notification-level";

export default class BulkTopicActions extends Component {
  @service router;

  async perform(operation) {
    this.loading = true;

    if (this.args.model.bulkSelectHelper.selected.length > 20) {
      this.showProgress = true;
    }

    try {
      return this._processChunks(operation);
    } catch {
      this.dialog.alert(i18n.t("generic_error"));
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
      chunks.push(allTopics.slice(startIndex, startIndex + chunkSize));
      startIndex += chunkSize;
    }

    return chunks;
  }

  _processChunks(operation) {
    const allTopics = this.args.model.bulkSelectHelper.selected;
    const topicChunks = this._generateTopicChunks(allTopics);
    const topicIds = [];
    const options = {};

    if (this.args.model.allowSilent === true) {
      options.silent = true;
    }

    const tasks = topicChunks.map((topics) => async () => {
      const result = await Topic.bulkOperation(topics, operation, options);
      this.processedTopicCount += topics.length;
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
    switch (this.args.model.action) {
      case "close":
        this.forEachPerformed({ type: "close" }, (t) => t.set("closed", true));
        break;
      case "archive":
        this.forEachPerformed({ type: "archive" }, (t) => t.set("archived", true));
        break;
      case "unlist":
        this.forEachPerformed({ type: "unlist" }, (t) => t.set("unlisted", true));
        break;
      case "delete":
        this.performAndRefresh({ type: "delete" });
        break;
      case "reset-bump-dates":
        this.performAndRefresh({ type: "reset_bump_dates" });
        break;
      case "defer":
        this.performAndRefresh({ type: "destroy_post_timing" });
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
      this.args.model.bulkSelectHelper.toggleBulkSelect();
    }
  }

  @action
  async performAndRefresh(operation) {
    await this.perform(operation);

    this.args.model.refreshClosure?.();
    this.args.closeModal();
    this.args.model.bulkSelectHelper.toggleBulkSelect();
  }

  <template>
    <DModal
      @title={{@model.title}}
      @closeModal={{@closeModal}}
      class="topic-bulk-actions-modal -large"
    >
      <:body>
        <div>
          {{htmlSafe (i18n "topics.bulk.selected" count=this.args.model.bulkSelectHelper.selected.length)}}
        </div>
      </:body>

      <:footer>
        {{#if @model.allowSilent}}
          <div class="topic-bulk-actions-options">
            <label
              for="topic-bulk-action-options__silent"
              class="checkbox-label"
            >
              <input
                class=""
                id="topic-bulk-action-options__silent"
                type="checkbox"
              />{{i18n "topics.bulk.silent"}}</label>
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
