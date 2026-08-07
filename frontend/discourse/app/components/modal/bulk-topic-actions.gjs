import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { Promise } from "rsvp";
import ManageTagsForm from "discourse/components/modal/bulk-topic-actions/manage-tags-form";
import BulkPinOptions from "discourse/components/modal/feature-topic/bulk-pin-options";
import { topicLevels } from "discourse/lib/notification-levels";
import renderTag from "discourse/lib/render-tag";
import { escapeExpression } from "discourse/lib/utilities";
import Category from "discourse/models/category";
import Topic from "discourse/models/topic";
import CategoryChooser from "discourse/select-kit/components/category-chooser";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSection from "discourse/ui-kit/d-conditional-loading-section";
import DModal from "discourse/ui-kit/d-modal";
import DRadioButton from "discourse/ui-kit/d-radio-button";
import { categoryBadgeHTML } from "discourse/ui-kit/helpers/d-category-link";
import dAutoFocus from "discourse/ui-kit/modifiers/d-auto-focus";
import { i18n } from "discourse-i18n";

const _customActions = {};

export function addBulkDropdownAction(name, customAction) {
  _customActions[name] = customAction;
}

export default class BulkTopicActions extends Component {
  @service toasts;

  @tracked activeComponent = null;
  @tracked activeComponentProps = null;
  @tracked categoryId;
  @tracked loading;
  @tracked errors;
  @tracked notifyUsers = false;
  @tracked closeNote = null;
  @tracked failureMessages = null;
  @tracked successTopicCount = 0;
  @tracked skippedTopicCount = 0;

  @tracked notificationLevelId = null;
  @tracked customSubmitDisabled = false;

  constructor() {
    super(...arguments);

    if (this.model.action === "manage-tags") {
      this.setComponent(ManageTagsForm, {
        categoryId: this.soleCategoryId,
        onPerform: this.performAndRefresh,
      });
    } else if (this.model.initialAction === "set-component") {
      if (this.model.initialActionLabel in _customActions) {
        _customActions[this.model.initialActionLabel]({
          setComponent: this.setComponent.bind(this),
          topics: this.model.bulkSelectHelper.selected,
          performAndRefresh: this.performAndRefresh.bind(this),
          forEachPerformed: this.forEachPerformed.bind(this),
          afterBulkAction: () => {
            this.model.refreshClosure?.();
            this.args.closeModal();
            this.model.bulkSelectHelper.toggleBulkSelect();
          },
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
    const mergedErrors = {};
    const mergedTagCategoryErrors = {};
    const options = {};

    if (this.model.allowSilent) {
      operation.silent = !this.notifyUsers;
    }

    if (this.isCloseAction && this.closeNote) {
      operation["message"] = this.closeNote;
    }

    if (operation.type === "manage_tags") {
      options.asJSON = true;
    }

    const tasks = topicChunks.map((topics) => async () => {
      const result = await Topic.bulkOperation(topics, operation, options);
      this.processedTopicCount += topics.length;
      return result;
    });

    return new Promise((resolve, reject) => {
      const resolveNextTask = async () => {
        if (tasks.length === 0) {
          const topics = topicIds.map((id) =>
            allTopics.find((value) => value.id === id)
          );
          const errors = Object.keys(mergedErrors).length ? mergedErrors : null;
          const tagCategoryErrors = Object.values(mergedTagCategoryErrors);
          return resolve({
            topics,
            errors,
            tagCategoryErrors: tagCategoryErrors.length
              ? tagCategoryErrors
              : null,
          });
        }

        const task = tasks.shift();

        try {
          const result = await task();
          if (result?.topic_ids) {
            topicIds.push(...result.topic_ids);
          }
          if (result?.errors) {
            for (const [msg, count] of Object.entries(result.errors)) {
              mergedErrors[msg] = (mergedErrors[msg] || 0) + count;
            }
          }
          if (result?.tag_category_errors) {
            for (const error of result.tag_category_errors) {
              const key = `${error.category_id}:${error.tag_names.join(",")}`;
              if (mergedTagCategoryErrors[key]) {
                mergedTagCategoryErrors[key].count += error.count;
              } else {
                mergedTagCategoryErrors[key] = { ...error };
              }
            }
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
  setComponent(component, props = {}) {
    this.activeComponent = component;
    this.activeComponentProps = props;
  }

  @action
  registerCustomAction(customAction) {
    this.customAction = customAction;
  }

  @action
  performAction(opts = {}) {
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
        let params = { type: this.model.action };

        let userPrivateMessages = getOwner(this).lookup(
          "controller:user-private-messages"
        );

        if (userPrivateMessages.isGroup) {
          params.group = userPrivateMessages.groupFilter;
        }

        let groupPrivateMessages = getOwner(this).lookup(
          "controller:group.messages"
        );

        if (groupPrivateMessages.isGroup) {
          params.group = groupPrivateMessages.model.name;
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
      case "unpin":
        this.forEachPerformed({ type: "unpin" }, (t) => t.set("pinned", false));
        break;
      case "enable-nested-replies":
        this.forEachPerformed({ type: "enable_nested_view" }, (t) =>
          t.set("is_nested_view", true)
        );
        break;
      case "disable-nested-replies":
        this.forEachPerformed({ type: "disable_nested_view" }, (t) =>
          t.set("is_nested_view", false)
        );
        break;
      case "pin":
        this.performAndRefresh({ type: "pin", ...opts });
        break;
      case "delete":
        this.performAndRefresh({ type: "delete" });
        break;
      case "reset-bump-dates":
        this.performAndRefresh({ type: "reset_bump_dates" });
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
      case "convert-to-public-topic":
        this.performAndRefresh({
          type: "convert_to_public_topic",
          category_id: this.categoryId,
        });
        break;
      case "convert-to-private-message":
        this.performAndRefresh({ type: "convert_to_private_message" });
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
        duration: "short",
        data: { message: i18n("generic_error") },
      });
    } else {
      this.toasts.success({
        duration: "short",
        data: { message: i18n("topics.bulk.completed") },
      });
    }
  }

  get failedTopicCount() {
    return (this.failureMessages || []).reduce((sum, e) => sum + e.count, 0);
  }

  get hasFailures() {
    return this.failedTopicCount > 0;
  }

  _buildTagCategoryError(error) {
    const category = Category.findById(error.category_id);
    return i18n("topics.bulk.tag_not_allowed_in_category", {
      count: error.tag_names.length,
      tags: error.tag_names.map((name) => renderTag(name)).join(" "),
      category: category
        ? categoryBadgeHTML(category)
        : escapeExpression(error.category_name),
    });
  }

  _showErrors(errors, tagCategoryErrors, successCount, totalCount) {
    this.failureMessages = [
      ...(tagCategoryErrors || []).map((error) => ({
        message: this._buildTagCategoryError(error),
        count: error.count,
        trustHtml: true,
      })),
      ...Object.entries(errors || {}).map(([message, count]) => ({
        message,
        count,
      })),
    ];
    this.successTopicCount = successCount;
    this.skippedTopicCount = totalCount - successCount - this.failedTopicCount;
    this.loading = false;
  }

  @action
  closeWithRefresh() {
    this.model.refreshClosure?.();
    this.model.bulkSelectHelper.toggleBulkSelect();
    this.args.closeModal();
  }

  @action
  async forEachPerformed(operation, cb) {
    this.loading = true;
    const totalCount = this.model.bulkSelectHelper.selected.length;
    const result = await this.perform(operation);

    if (result) {
      const { topics, errors, tagCategoryErrors } = result;
      topics.forEach(cb);

      if (errors || tagCategoryErrors) {
        this._showErrors(errors, tagCategoryErrors, topics.length, totalCount);
      } else {
        this.model.refreshClosure?.();
        this.args.closeModal();
        this.model.bulkSelectHelper.toggleBulkSelect();
        this.showToast();
      }
    }
  }

  @action
  async performAndRefresh(operation) {
    this.loading = true;
    const totalCount = this.model.bulkSelectHelper.selected.length;
    const result = await this.perform(operation);

    if (result) {
      const { topics, errors, tagCategoryErrors } = result;
      if (errors || tagCategoryErrors) {
        this._showErrors(errors, tagCategoryErrors, topics.length, totalCount);
      } else {
        this.model.refreshClosure?.().then(() => {
          this.args.closeModal();
          this.model.bulkSelectHelper.toggleBulkSelect();
          this.showToast();
        });
      }
    }
  }

  get isNotificationAction() {
    return this.model.action === "update-notifications";
  }

  get isCategoryAction() {
    return (
      this.model.action === "update-category" ||
      this.model.action === "convert-to-public-topic"
    );
  }

  get isCloseAction() {
    return this.model.action === "close";
  }

  get isPinAction() {
    return this.model.action === "pin";
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

  get confirmButtonLabel() {
    if (this.model.confirmButtonTranslationKey) {
      return i18n(this.model.confirmButtonTranslationKey, {
        count: this.model.bulkSelectHelper.selected.length,
      });
    }
    return i18n("topics.bulk.confirm");
  }

  get disabledSubmit() {
    if (this.isNotificationAction) {
      return !this.notificationLevelId || this.loading;
    }

    return this.customSubmitDisabled || this.loading;
  }

  @action
  setSubmitDisabled(value) {
    this.customSubmitDisabled = value;
  }

  @action
  onCategoryChange(categoryId) {
    this.categoryId = categoryId;
  }

  <template>
    <DModal
      @title={{@model.title}}
      @closeModal={{@closeModal}}
      class="topic-bulk-actions-modal"
    >
      <:body>
        <DConditionalLoadingSection
          @isLoading={{this.loading}}
          @title={{i18n "topics.bulk.performing"}}
        >
          {{#if this.hasFailures}}
            <div class="topic-bulk-actions-modal__errors">
              {{#if this.successTopicCount}}
                <p>{{trustHTML
                    (i18n
                      "topics.bulk.completed_count" count=this.successTopicCount
                    )
                  }}</p>
              {{/if}}
              {{#if this.skippedTopicCount}}
                <p>{{trustHTML
                    (i18n
                      "topics.bulk.skipped_count" count=this.skippedTopicCount
                    )
                  }}</p>
              {{/if}}
              <p>{{trustHTML
                  (i18n "topics.bulk.not_completed" count=this.failedTopicCount)
                }}</p>
              <ul>
                {{#each this.failureMessages as |error|}}
                  <li>
                    {{#if error.trustHtml}}
                      {{trustHTML error.message}}
                    {{else}}
                      {{error.message}}
                    {{/if}}
                    ({{i18n
                      "topics.bulk.error_topic_count"
                      count=error.count
                    }})</li>
                {{/each}}
              </ul>
            </div>
          {{else}}
            {{#if @model.description}}
              <p class="topic-bulk-actions-modal__description">{{trustHTML
                  @model.description
                }}</p>
            {{/if}}

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
                    <label
                      class="radio notification-level-radio checkbox-label"
                    >
                      <DRadioButton
                        @value={{level.id}}
                        @name="notification_level"
                        @selection={{this.notificationLevelId}}
                      />
                      <strong>{{level.name}}</strong>
                      <div class="description">{{trustHTML
                          level.description
                        }}</div>
                    </label>
                  </div>
                {{/each}}
              </div>
            {{/if}}

            {{#if this.activeComponent}}
              {{component
                this.activeComponent
                onRegisterAction=this.registerCustomAction
                setSubmitDisabled=this.setSubmitDisabled
                topics=this.activeComponentProps.topics
                afterBulkAction=this.activeComponentProps.afterBulkAction
                categoryId=this.activeComponentProps.categoryId
                onPerform=this.activeComponentProps.onPerform
              }}
            {{/if}}

            {{#if this.isPinAction}}
              <BulkPinOptions
                @onPin={{this.performAction}}
                @category={{this.soleCategory}}
              />
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
                  {{dAutoFocus}}
                >{{this.closeNote}}</textarea>
              </div>
            {{/if}}
          {{/if}}
        </DConditionalLoadingSection>
      </:body>

      <:footer>
        {{#if this.hasFailures}}
          <DButton
            @action={{this.closeWithRefresh}}
            @label="close"
            class="btn-primary"
            id="bulk-topics-close"
          />
        {{else if @model.showFooter}}
          {{#if @model.allowSilent}}
            <div class="topic-bulk-actions-options">
              <label
                for="topic-bulk-action-options__notify"
                class="checkbox-label"
              >
                <Input
                  id="topic-bulk-action-options__notify"
                  @type="checkbox"
                  @checked={{this.notifyUsers}}
                />{{i18n "topics.bulk.notify"}}</label>
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
            @disabled={{this.disabledSubmit}}
            @translatedLabel={{this.confirmButtonLabel}}
            id="bulk-topics-confirm"
            class="btn-primary"
          />
        {{/if}}
      </:footer>

    </DModal>
  </template>
}
