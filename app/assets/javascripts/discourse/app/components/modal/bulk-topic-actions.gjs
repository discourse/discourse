import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { Promise } from "rsvp";
import ConditionalLoadingSection from "discourse/components/conditional-loading-section";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import RadioButton from "discourse/components/radio-button";
import { categoryBadgeHTML } from "discourse/helpers/category-link";
import { topicLevels } from "discourse/lib/notification-levels";
import Category from "discourse/models/category";
import Topic from "discourse/models/topic";
import autoFocus from "discourse/modifiers/auto-focus";
import { i18n } from "discourse-i18n";
import CategoryChooser from "select-kit/components/category-chooser";
import TagChooser from "select-kit/components/tag-chooser";

const _customActions = {};

export function addBulkDropdownAction(name, customAction) {
  _customActions[name] = customAction;
}

export default class BulkTopicActions extends Component {
  @service router;
  @service toasts;
  @tracked activeComponent = null;
  @tracked tags = [];
  @tracked categoryId;
  @tracked loading;
  @tracked errors;
  @tracked isSilent = false;
  @tracked closeNote = null;

  notificationLevelId = null;

  constructor() {
    super(...arguments);

    if (this.model.initialAction === "set-component") {
      if (this.model.initialActionLabel in _customActions) {
        _customActions[this.model.initialActionLabel]({
          setComponent: this.setComponent.bind(this),
        });
      }
    }
  }

  async perform(operation) {
    if (this.model.bulkSelectHelper.selected.length > 20) {
      this.showProgress = true;
    }

    try {
      return await this._processChunks(operation);
    } catch {
      this.errors = true;
      this.showToast();
    } finally {
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
    const allTopics = this.model.bulkSelectHelper.selected;
    const topicChunks = this._generateTopicChunks(allTopics);
    const topicIds = [];
    const options = {};

    if (this.isSilent) {
      const newType =
        operation.type === "close" ? "silent_close" : operation.type;
      operation.type = newType;
    }

    if (this.isCloseAction && this.closeNote) {
      operation["message"] = this.closeNote;
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
  registerCustomAction(customAction) {
    this.customAction = customAction;
  }

  @action
  performAction() {
    this.loading = true;
    switch (this.model.action) {
      case "close":
        this.forEachPerformed({ type: "close" }, (t) => t.set("closed", true));
        break;
      case "archive":
        this.forEachPerformed({ type: "archive" }, (t) =>
          t.set("archived", true)
        );
        break;
      case "archive_messages":
      case "move_messages_to_inbox":
        let userPrivateMessages = getOwner(this).lookup(
          "controller:user-private-messages"
        );

        let params = { type: this.model.action };

        if (userPrivateMessages.isGroup) {
          params.group = userPrivateMessages.groupFilter;
        }

        this.performAndRefresh(params);
        break;
      case "unlist":
        this.forEachPerformed({ type: "unlist" }, (t) =>
          t.set("unlisted", true)
        );
        break;
      case "relist":
        this.forEachPerformed({ type: "relist" }, (t) =>
          t.set("unlisted", false)
        );
        break;
      case "append-tags":
        this.performAndRefresh({ type: "append_tags", tags: this.tags });
        break;
      case "replace-tags":
        this.performAndRefresh({ type: "change_tags", tags: this.tags });
        break;
      case "remove-tags":
        this.performAndRefresh({ type: "remove_tags" });
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
      case "update-notifications":
        this.performAndRefresh({
          type: "change_notification_level",
          notification_level_id: this.notificationLevelId,
        });
        break;
      case "update-category":
        this.forEachPerformed(
          {
            type: "change_category",
            category_id: this.categoryId,
          },
          (t) => t.set("category_id", this.categoryId)
        );
        break;
      default:
        // Plugins can register their own custom actions via onRegisterAction
        // when the activeComponent is rendered.
        if (this.customAction) {
          this.customAction(this.performAndRefresh.bind(this));
        } else {
          _customActions[this.model.initialActionLabel](this);
        }
    }
  }

  showToast() {
    this.loading = false;
    if (this.errors) {
      this.toasts.error({
        duration: 3000,
        data: { message: i18n("generic_error") },
      });
    } else {
      this.toasts.success({
        duration: 3000,
        data: { message: i18n("topics.bulk.completed") },
      });
    }
  }

  @action
  async forEachPerformed(operation, cb) {
    const topics = await this.perform(operation);

    if (topics) {
      topics.forEach(cb);
      this.model.refreshClosure?.();
      this.args.closeModal();
      this.model.bulkSelectHelper.toggleBulkSelect();
      this.showToast();
    }
  }

  @action
  async performAndRefresh(operation) {
    await this.perform(operation);

    this.model.refreshClosure?.().then(() => {
      this.args.closeModal();
      this.model.bulkSelectHelper.toggleBulkSelect();
      this.showToast();
    });
  }

  get isTagAction() {
    return (
      this.model.action === "append-tags" ||
      this.model.action === "replace-tags"
    );
  }

  get isNotificationAction() {
    return this.model.action === "update-notifications";
  }

  get isCategoryAction() {
    return this.model.action === "update-category";
  }

  get isCloseAction() {
    return this.model.action === "close";
  }

  @action
  updateCloseNote(event) {
    event.preventDefault();
    this.closeNote = event.target.value;
  }

  get model() {
    return this.args.model;
  }

  get notificationLevels() {
    return topicLevels.map((level) => ({
      id: level.id.toString(),
      name: i18n(`topic.notifications.${level.key}.title`),
      description: i18n(`topic.notifications.${level.key}.description`),
    }));
  }

  get soleCategoryId() {
    if (this.model.bulkSelectHelper.selectedCategoryIds.length === 1) {
      return this.model.bulkSelectHelper.selectedCategoryIds[0];
    }

    return null;
  }

  get soleCategory() {
    if (!this.soleCategoryId) {
      return null;
    }

    return Category.findById(this.soleCategoryId);
  }

  get soleCategoryBadgeHTML() {
    return categoryBadgeHTML(this.soleCategory, {
      allowUncategorized: true,
    });
  }

  get showSoleCategoryTip() {
    return this.soleCategory && this.isTagAction;
  }

  @action
  onCategoryChange(categoryId) {
    this.categoryId = categoryId;
  }

  <template>
    <DModal
      @title={{@model.title}}
      @subtitle={{@model.description}}
      @closeModal={{@closeModal}}
      class="topic-bulk-actions-modal -large"
    >
      <:body>
        <ConditionalLoadingSection
          @isLoading={{this.loading}}
          @title={{i18n "topics.bulk.performing"}}
        >
          <div class="topic-bulk-actions-modal__selection-info">

            {{#if this.showSoleCategoryTip}}
              {{htmlSafe
                (i18n
                  "topics.bulk.selected_sole_category"
                  count=@model.bulkSelectHelper.selected.length
                )
              }}
              {{htmlSafe this.soleCategoryBadgeHTML}}
            {{else}}
              {{htmlSafe
                (i18n
                  "topics.bulk.selected"
                  count=@model.bulkSelectHelper.selected.length
                )
              }}

            {{/if}}
          </div>

          {{#if this.isCategoryAction}}
            <p>
              <CategoryChooser
                @value={{this.categoryId}}
                @onChange={{this.onCategoryChange}}
              />
            </p>
          {{/if}}

          {{#if this.isNotificationAction}}
            <div class="bulk-notification-list">
              {{#each this.notificationLevels as |level|}}
                <div class="controls">
                  <label class="radio notification-level-radio checkbox-label">
                    <RadioButton
                      @value={{level.id}}
                      @name="notification_level"
                      @selection={{this.notificationLevelId}}
                    />
                    <strong>{{level.name}}</strong>
                    <div class="description">{{htmlSafe
                        level.description
                      }}</div>
                  </label>
                </div>
              {{/each}}
            </div>
          {{/if}}

          {{#if this.isTagAction}}
            <p><TagChooser
                @tags={{this.tags}}
                @categoryId={{this.soleCategoryId}}
              /></p>
          {{/if}}

          {{#if this.activeComponent}}
            {{component
              this.activeComponent
              onRegisterAction=this.registerCustomAction
            }}
          {{/if}}

          {{#if this.isCloseAction}}
            <div class="bulk-close-note-section">
              <label>
                {{i18n "topic_bulk_actions.close_topics.note"}}&nbsp;<span
                  class="label-optional"
                >{{i18n "topic_bulk_actions.close_topics.optional"}}</span>
              </label>

              <textarea
                id="bulk-close-note"
                {{on "input" this.updateCloseNote}}
                {{autoFocus}}
              >{{this.closeNote}}</textarea>
            </div>
          {{/if}}
        </ConditionalLoadingSection>
      </:body>

      <:footer>
        {{#if @model.allowSilent}}
          <div class="topic-bulk-actions-options">
            <label
              for="topic-bulk-action-options__silent"
              class="checkbox-label"
            >
              <Input
                id="topic-bulk-action-options__silent"
                @type="checkbox"
                @checked={{this.isSilent}}
              />{{i18n "topics.bulk.silent"}}</label>
          </div>
        {{/if}}

        <DButton
          @action={{@closeModal}}
          @label="cancel"
          class="btn-transparent d-modal-cancel"
          id="bulk-topics-cancel"
        />
        <DButton
          @action={{this.performAction}}
          @disabled={{this.loading}}
          @icon="check"
          @label="topics.bulk.confirm"
          id="bulk-topics-confirm"
          class="btn-primary"
        />
      </:footer>

    </DModal>
  </template>
}
