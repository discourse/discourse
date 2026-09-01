import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn, get } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { trackedObject } from "@ember/reactive/collections";
import { service } from "@ember/service";
import { classify, dasherize } from "@ember/string";
import ScrubRejectedUserModal from "discourse/admin/components/modal/scrub-rejected-user";
import ExplainReviewableModal from "discourse/components/modal/explain-reviewable";
import RejectReasonReviewableModal from "discourse/components/modal/reject-reason-reviewable";
import ReviseAndRejectPostReviewable from "discourse/components/modal/revise-and-reject-post-reviewable";
import ReviewableFlagReason from "discourse/components/reviewable/flag-reason";
import ReviewableHelpResources from "discourse/components/reviewable/help-resources";
import ReviewableInsights from "discourse/components/reviewable/insights";
import ReviewableTimeline from "discourse/components/reviewable/timeline";
import ReviewableBundledAction from "discourse/components/reviewable-bundled-action";
import ReviewableClaimedTopic from "discourse/components/reviewable-claimed-topic";
import ReviewableCreatedBy from "discourse/components/reviewable-created-by";
import ReviewableFieldCategory from "discourse/components/reviewable-field-category";
import ReviewableFieldEditor from "discourse/components/reviewable-field-editor";
import ReviewableFieldTags from "discourse/components/reviewable-field-tags";
import ReviewableFieldText from "discourse/components/reviewable-field-text";
import ReviewableFieldTextarea from "discourse/components/reviewable-field-textarea";
import editableValue from "discourse/helpers/editable-value";
import { newReviewableStatus } from "discourse/helpers/reviewable-status";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import { getAbsoluteURL } from "discourse/lib/get-url";
import optionalService from "discourse/lib/optional-service";
import { showAlert } from "discourse/lib/post-action-feedback";
import { resolveReviewableComponent } from "discourse/lib/reviewable-registry";
import { clipboardCopy } from "discourse/lib/utilities";
import Category from "discourse/models/category";
import Composer from "discourse/models/composer";
import { PENDING } from "discourse/models/reviewable";
import { CLAIMED, UNCLAIMED } from "discourse/models/reviewable-history";
import Topic from "discourse/models/topic";
import { eq, not } from "discourse/truth-helpers";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import DButton from "discourse/ui-kit/d-button";
import DHorizontalOverflowNav from "discourse/ui-kit/d-horizontal-overflow-nav";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dDasherize from "discourse/ui-kit/helpers/d-dasherize";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const fieldComponents = {
  category: ReviewableFieldCategory,
  editor: ReviewableFieldEditor,
  tags: ReviewableFieldTags,
  text: ReviewableFieldText,
  textarea: ReviewableFieldTextarea,
};

export const pluginReviewableParams = {};
const reviewableTypeLabels = {};

// The mappings defined here are default core mappings, and cannot be overridden
// by plugins.
const defaultActionModalClassMap = {
  revise_and_reject_post: ReviseAndRejectPostReviewable,
};
export const actionModalClassMap = { ...defaultActionModalClassMap };

export function addPluginReviewableParam(reviewableType, param) {
  pluginReviewableParams[reviewableType]
    ? pluginReviewableParams[reviewableType].push(param)
    : (pluginReviewableParams[reviewableType] = [param]);
}

export function registerReviewableActionModal(actionName, modalClass) {
  if (Object.keys(defaultActionModalClassMap).includes(actionName)) {
    throw new Error(
      `Cannot override default action modal class for ${actionName} (mapped to ${defaultActionModalClassMap[actionName].name})!`
    );
  }
  actionModalClassMap[actionName] = modalClass;
}

/**
 * Registers a custom label translation key for a reviewable type.
 * Plugins can use this to provide specific labels for their reviewable types.
 *
 * @param {string} reviewableType - The reviewable type class name (e.g., "ReviewableAiPost")
 * @param {string} labelKey - The i18n translation key (e.g., "discourse_ai.review.ai_post_flagged_as")
 *
 * @example
 * import { registerReviewableTypeLabel } from "discourse/components/reviewable/item";
 * registerReviewableTypeLabel("ReviewableAiPost", "discourse_ai.review.ai_post_flagged_as");
 */
export function registerReviewableTypeLabel(reviewableType, labelKey) {
  reviewableTypeLabels[reviewableType] = labelKey;
}

export default class ReviewableItem extends Component {
  @service dialog;
  @service modal;
  @service siteSettings;
  @service currentUser;
  @service composer;
  @service store;
  @service toasts;
  @service messageBus;
  @optionalService adminTools;

  @tracked disabled = false;
  @tracked updating = false;

  constructor() {
    super(...arguments);
    this.messageBus.subscribe("/reviewable_claimed", this._updateClaimedBy);
    this.messageBus.subscribe("/reviewable_action", this._updateStatus);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.messageBus.unsubscribe("/reviewable_claimed", this._updateClaimedBy);
    this.messageBus.unsubscribe("/reviewable_action", this._updateStatus);
  }

  @cached
  get state() {
    // reading the argument is what ties this cache to a single reviewable
    this.args.reviewable;

    return trackedObject({
      activeTab: "timeline",
      insightsOpened: false,
      updates: null,
    });
  }

  get editing() {
    return this.state.updates !== null;
  }

  get customClasses() {
    const { reviewable } = this.args;
    let classes = dasherize(reviewable?.type);

    if (reviewable?.last_performing_username) {
      classes = `${classes} reviewable-stale`;
    }

    if (
      this.siteSettings?.blur_tl0_flagged_posts_media &&
      reviewable?.target_created_by_trust_level === 0
    ) {
      classes = `${classes} blur-images`;
    }

    if (reviewable?.deleted_at) {
      classes = `${classes} reviewable-deleted`;
    }

    return classes;
  }

  get displayContextQuestion() {
    const { reviewable } = this.args;

    return (
      (reviewable?.created_from_flag &&
        reviewable?.status === PENDING &&
        (this.claimOptional ||
          (this.claimRequired && reviewable?.claimed_by !== null))) ||
      this.isAiReviewable
    );
  }

  get isAiReviewable() {
    const { type } = this.args.reviewable ?? {};

    return type === "ReviewableAiChatMessage" || type === "ReviewableAiPost";
  }

  get topicId() {
    const { reviewable } = this.args;

    return (
      reviewable?.topic?.id ||
      reviewable?.topic_id ||
      reviewable?.removed_topic_id
    );
  }

  get claimEnabled() {
    const { reviewable } = this.args;

    return (
      (this.siteSettings?.reviewable_claiming !== "disabled" ||
        reviewable?.claimed_by?.automatic) &&
      !!this.topicId &&
      reviewable?.status === PENDING
    );
  }

  get claimOptional() {
    return (
      !this.claimEnabled ||
      this.siteSettings?.reviewable_claiming === "optional"
    );
  }

  get claimRequired() {
    return (
      this.claimEnabled && this.siteSettings?.reviewable_claiming === "required"
    );
  }

  get canPerform() {
    const { reviewable } = this.args;

    if (reviewable?.bundled_actions?.length === 0) {
      return false;
    }
    if (!this.claimEnabled) {
      return true;
    }

    if (reviewable?.claimed_by) {
      return reviewable.claimed_by.user.id === this.currentUser.id;
    }

    return this.siteSettings?.reviewable_claiming !== "required";
  }

  get tagCategoryId() {
    return (
      this.state.updates?.category_id || this.args.reviewable?.category?.id
    );
  }

  get scoreSummary() {
    const scoreData = this.args.reviewable?.reviewable_scores?.reduce(
      (acc, score) => {
        if (!acc[score.score_type.type]) {
          acc[score.score_type.type] = {
            title: score.score_type.title,
            type: score.score_type.type,
            count: 0,
          };
        }

        acc[score.score_type.type].count += 1;
        return acc;
      },
      {}
    );

    return Object.values(scoreData);
  }

  get reviewableTypeLabel() {
    const { reviewable } = this.args;

    // handle plugin types
    if (reviewableTypeLabels[reviewable?.type]) {
      return reviewableTypeLabels[reviewable?.type];
    }

    // core types
    if (reviewable?.type === "ReviewableUser") {
      return "review.user_label";
    }

    if (reviewable?.type === "ReviewableQueuedPost") {
      // if topic_id is null it's a new topic
      return this.topicId
        ? "review.queued_post_label"
        : "review.queued_topic_label";
    }

    if (reviewable?.type === "ReviewableChatMessage") {
      return "review.chat_flagged_as";
    }

    if (reviewable?.created_from_flag) {
      return "review.post_flagged_as";
    }

    // fallback
    return "review.flagged_as";
  }

  get permalink() {
    return getAbsoluteURL(`/review/${this.args.reviewable.id}`);
  }

  @bind
  resolveReviewableComponent(type) {
    return resolveReviewableComponent(getOwner(this), type);
  }

  @action
  clientScrub() {
    this.modal.show(ScrubRejectedUserModal, {
      model: {
        confirmScrub: this.scrubRejectedUser,
      },
    });
  }

  @bind
  async scrubRejectedUser(reason) {
    const { id } = this.args.reviewable;

    try {
      await ajax({ url: `/review/${id}/scrub`, type: "PUT", data: { reason } });
      this.store.find("reviewable", id);
    } catch (e) {
      popupAjaxError(e);
    }
  }

  clientSuspend(reviewable, performAction) {
    return this._penalize("showSuspendModal", reviewable, performAction);
  }

  clientSilence(reviewable, performAction) {
    return this._penalize("showSilenceModal", reviewable, performAction);
  }

  async clientEdit(reviewable, performAction) {
    if (!this.currentUser) {
      return this.dialog.alert(i18n("post.controls.edit_anonymous"));
    }
    const post = await this.store.find("post", reviewable.post_id);
    const topic_json = await Topic.find(post.topic_id, {});

    const topic = Topic.create(topic_json);
    post.set("topic", topic);

    if (!post.can_edit) {
      return false;
    }

    const opts = {
      post,
      action: Composer.EDIT,
      draftKey: post.get("topic.draft_key"),
      draftSequence: post.get("topic.draft_sequence"),
      skipJumpOnSave: true,
    };

    this.composer.open(opts);

    return performAction();
  }

  @action
  explainReviewable(reviewable, event) {
    event.preventDefault();
    this.modal.show(ExplainReviewableModal, {
      model: { reviewable },
    });
  }

  @action
  switchTab(tabName, event) {
    event.preventDefault();
    this.state.activeTab = tabName;
    if (tabName === "insights") {
      this.state.insightsOpened = true;
    }
  }

  @action
  edit() {
    this.state.updates = trackedObject({});
  }

  @action
  cancelEdit() {
    this.state.updates = null;
  }

  @action
  saveEdit() {
    this.updating = true;
    return this.args.reviewable
      .update({ ...this.state.updates })
      .then(() => (this.state.updates = null))
      .catch(popupAjaxError)
      .finally(() => (this.updating = false));
  }

  @action
  categoryChanged(categoryId) {
    const category =
      Category.findById(categoryId) ?? Category.findUncategorized();

    this.#updateField("category_id", category.id);
  }

  @action
  valueChanged(fieldId, event) {
    this.#updateField(fieldId, event.target.value);
  }

  @action
  async perform(performableAction) {
    if (this.updating) {
      return;
    }

    const message = performableAction.get("confirm_message");
    const requireRejectReason = performableAction.get("require_reject_reason");
    const actionModalClass = requireRejectReason
      ? RejectReasonReviewableModal
      : actionModalClassMap[performableAction.server_action];

    if (message) {
      if (await this.#claimReviewable()) {
        const confirmOptions = {
          message,
          didConfirm: () => this._performConfirmed(performableAction),
          // Claiming happens before the prompt, so release it if nothing is performed.
          didCancel: () => this.#unclaimAutomaticReviewable(),
        };

        if (performableAction.get("confirm_destructive")) {
          this.dialog.deleteConfirm(confirmOptions);
        } else {
          this.dialog.confirm(confirmOptions);
        }
      }
    } else if (actionModalClass) {
      if (await this.#claimReviewable()) {
        this.modal.show(actionModalClass, {
          model: {
            reviewable: this.args.reviewable,
            performConfirmed: this._performConfirmed,
            action: performableAction,
          },
        });
      }
    } else {
      return this._performConfirmed(performableAction);
    }
  }

  @action
  claimedByChanged(claimedBy) {
    this.args.reviewable.claimed_by = claimedBy;
  }

  @action
  async copyPermalink(event) {
    const button = event.currentTarget;

    // cmd/ctrl+click or middle-click to open in new tab
    if (event.metaKey || event.ctrlKey || event.button === 1) {
      window.open(this.permalink, "_blank");
      return;
    }

    try {
      await clipboardCopy(this.permalink);
      showAlert(
        this.args.reviewable.id,
        "reviewable-permalink-copy",
        "review.copy_link_feedback",
        { actionBtn: button }
      );
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error("Failed to copy to clipboard:", error);
    }
  }

  async #claimReviewable() {
    const { reviewable } = this.args;

    if (!reviewable.topic) {
      // We can't claim a reviewable without a topic, so treat it as claimed
      return true;
    }

    if (!reviewable.claimed_by) {
      const claim = this.store.createRecord("reviewable-claimed-topic");

      try {
        await claim.save({ topic_id: reviewable.topic.id, automatic: true });
        reviewable.claimed_by = { user: this.currentUser, automatic: true };
      } catch (e) {
        popupAjaxError(e);
        return false;
      }
    }

    return reviewable.claimed_by?.user?.id === this.currentUser.id;
  }

  async #unclaimAutomaticReviewable() {
    const { reviewable } = this.args;

    if (!reviewable.topic || !reviewable.claimed_by?.automatic) {
      return;
    }

    try {
      await ajax(`/reviewable_claimed_topics/${reviewable.topic.id}`, {
        type: "DELETE",
        data: { automatic: true },
      });
      reviewable.claimed_by = null;
    } catch (e) {
      popupAjaxError(e);
    }
  }

  #updateField(fieldId, value) {
    const [key, nestedKey] = fieldId.split(".");
    const updates = this.state.updates;

    if (nestedKey) {
      updates[key] = { ...updates[key], [nestedKey]: value };
    } else {
      updates[key] = value;
    }
  }

  @bind
  _updateClaimedBy(data) {
    if (data.topic_id !== this.topicId) {
      return;
    }

    const { reviewable } = this.args;
    const user = this.store.createRecord("user", data.user);

    reviewable.claimed_by = data.claimed
      ? { user, automatic: data.automatic }
      : null;

    if (data.automatic || reviewable.status !== PENDING) {
      return;
    }

    reviewable.reviewable_histories = [
      ...reviewable.reviewable_histories,
      {
        reviewable_history_type: data.claimed ? CLAIMED : UNCLAIMED,
        created_at: new Date().toISOString(),
        created_by: user,
      },
    ];
  }

  @bind
  _updateStatus(data) {
    const { reviewable } = this.args;

    if (data.remove_reviewable_ids?.includes(reviewable.id)) {
      delete data.remove_reviewable_ids;
      this._performResult(data, {}, reviewable);
    }
  }

  @bind
  async _performConfirmed(performableAction, additionalData = {}) {
    let reviewable = this.args.reviewable;

    let performAction = async () => {
      this.disabled = true;

      let version = reviewable.version;
      this.updating = true;

      const data = {
        send_email: reviewable.sendEmail,
        reject_reason: reviewable.rejectReason,
        ...additionalData,
      };

      (pluginReviewableParams[reviewable.type] || []).forEach((param) => {
        if (reviewable[param]) {
          data[param] = reviewable[param];
        }
      });

      return ajax(
        `/review/${reviewable.id}/perform/${performableAction.server_action}?version=${version}`,
        {
          type: "PUT",
          dataType: "json",
          data,
        }
      )
        .then((result) =>
          this._performResult(
            result.reviewable_perform_result,
            performableAction,
            reviewable
          )
        )
        .finally(() => {
          this.updating = false;
          this.disabled = false;
        });
    };

    try {
      if (performableAction.client_action) {
        let actionMethod =
          this[`client${classify(performableAction.client_action)}`];
        if (actionMethod) {
          if (await this.#claimReviewable()) {
            await actionMethod.call(this, reviewable, performAction);
          }
        } else {
          // eslint-disable-next-line no-console
          console.error(
            `No handler for ${performableAction.client_action} found`
          );
        }
      } else {
        await performAction();
      }
    } catch (error) {
      popupAjaxError(error);
    }

    return this.#unclaimAutomaticReviewable();
  }

  _performResult(result, performableAction, reviewable) {
    // "fast track" to update the current user's reviewable count before the message bus finds out.
    if (result.reviewable_count !== undefined) {
      this.currentUser.updateReviewableCount(result.reviewable_count);
    }

    if (result.unseen_reviewable_count !== undefined) {
      this.currentUser.set(
        "unseen_reviewable_count",
        result.unseen_reviewable_count
      );
    }

    if (performableAction.completed_message) {
      this.toasts.success({
        data: { message: performableAction.completed_message },
      });
    }

    if (this.args.remove && result.remove_reviewable_ids?.length > 0) {
      this.args.remove(result.remove_reviewable_ids);
    } else {
      if (this.args.updateStatuses && result.reviewable_updates) {
        this.args.updateStatuses(result.reviewable_updates);
      }

      return this.store.find("reviewable", reviewable.id);
    }
  }

  _penalize(adminToolMethod, reviewable, performAction) {
    let adminTools = this.adminTools;
    if (adminTools) {
      let createdBy = reviewable.target_created_by;
      let postId = reviewable.post_id;
      let postEdit = reviewable.raw ?? reviewable.payload?.raw;

      return adminTools[adminToolMethod](createdBy, {
        postId,
        postEdit,
        reviewableId: reviewable.id,
        before: performAction,
      });
    }
  }

  <template>
    <div class="review-container">

      <div
        data-reviewable-id={{@reviewable.id}}
        class="review-item {{this.customClasses}}"
      >
        <div class="review-item__primary-content">
          <div class="review-item__flag-summary">
            <div class="review-item__header">
              <div class="review-item__label-badges">
                <span class="review-item__flag-label">{{i18n
                    this.reviewableTypeLabel
                  }}</span>

                <div class="review-item__flag-badges">
                  {{#each this.scoreSummary as |score|}}
                    <ReviewableFlagReason @score={{score}} />
                  {{/each}}
                </div>
              </div>

              <button
                type="button"
                {{on "click" this.copyPermalink}}
                title={{i18n "review.copy_permalink_title"}}
                class="btn btn-transparent reviewable-permalink-copy"
              >
                {{dIcon "link"}}
              </button>

              {{newReviewableStatus @reviewable.status @reviewable.type}}

              <span class="reviewable-created-date">
                {{dFormatDate @reviewable.created_at format="tiny"}}
              </span>

            </div>
            {{#if this.editing}}
              <div class="editable-fields">
                {{#each @reviewable.editable_fields as |f|}}
                  <div class="editable-field {{dDasherize f.id}}">
                    {{#let (get fieldComponents f.type) as |FieldComponent|}}
                      <FieldComponent
                        @tagName=""
                        @value={{editableValue @reviewable f.id}}
                        @tagCategoryId={{this.tagCategoryId}}
                        @valueChanged={{fn this.valueChanged f.id}}
                        @categoryChanged={{this.categoryChanged}}
                      />
                    {{/let}}
                  </div>
                {{/each}}
              </div>
            {{else}}
              <DAsyncContent
                @asyncData={{this.resolveReviewableComponent}}
                @context={{@reviewable.type}}
              >
                <:content as |ReviewableComponent|>
                  <ReviewableComponent
                    @reviewable={{@reviewable}}
                    @tagName=""
                  />
                </:content>
                <:empty>
                  <div class="alert alert-error review-item__no-component">
                    {{i18n "review.no_component_found" type=@reviewable.type}}
                  </div>
                </:empty>
              </DAsyncContent>
            {{/if}}
          </div>

          <div class="review-item__insights">
            <div class="d-nav-submenu">
              <DHorizontalOverflowNav
                @ariaLabel="Review tabs"
                class="d-nav-submenu__tabs"
              >
                <li
                  class={{dConcatClass
                    "timeline"
                    (if (eq this.state.activeTab "timeline") "active")
                  }}
                >
                  <a
                    href="#"
                    class={{if (eq this.state.activeTab "timeline") "active"}}
                    {{on "click" (fn this.switchTab "timeline")}}
                  >
                    {{i18n "review.timeline_and_notes"}}
                  </a>
                </li>
                <li
                  class={{dConcatClass
                    "insights"
                    (if (eq this.state.activeTab "insights") "active")
                  }}
                >
                  <a
                    href="#"
                    class={{if (eq this.state.activeTab "insights") "active"}}
                    {{on "click" (fn this.switchTab "insights")}}
                  >
                    {{i18n "review.insights.title"}}
                  </a>
                </li>
              </DHorizontalOverflowNav>
            </div>

            {{#if this.state.insightsOpened}}
              <div hidden={{not (eq this.state.activeTab "insights")}}>
                <ReviewableInsights @reviewable={{@reviewable}} />
              </div>
            {{/if}}
            {{#if (eq this.state.activeTab "timeline")}}
              <ReviewableTimeline
                @reviewable={{@reviewable}}
                @historyEvents={{@reviewable.reviewable_histories}}
              />
            {{/if}}
          </div>
        </div>

        <div class="review-item__aside">

          {{#unless @reviewable.last_performing_username}}
            {{#if this.canPerform}}
              <div class="review-item__moderator-actions">
                <h3 class="review-item__aside-title">
                  {{#if this.editing}}
                    {{i18n "review.editing_post"}}
                  {{else if this.displayContextQuestion}}
                    {{@reviewable.flaggedReviewableContextQuestion}}
                  {{else if @reviewable.userReviewableContextQuestion}}
                    {{@reviewable.userReviewableContextQuestion}}
                  {{else}}
                    {{i18n "review.moderator_actions"}}
                  {{/if}}
                </h3>
                {{#if this.editing}}
                  <DButton
                    @disabled={{this.disabled}}
                    @icon="check"
                    @action={{this.saveEdit}}
                    @label="review.save"
                    class="btn-primary reviewable-action save-edit"
                  />
                  <DButton
                    @disabled={{this.disabled}}
                    @icon="xmark"
                    @action={{this.cancelEdit}}
                    @label="review.cancel"
                    class="btn-danger reviewable-action cancel-edit"
                  />
                {{else}}
                  {{#each @reviewable.bundled_actions as |bundle|}}
                    <ReviewableBundledAction
                      @bundle={{bundle}}
                      @performAction={{this.perform}}
                      @reviewableUpdating={{this.disabled}}
                    />
                  {{/each}}

                  {{#if @reviewable.can_edit}}
                    <DButton
                      @disabled={{this.disabled}}
                      @action={{this.edit}}
                      @label="review.edit"
                      class="reviewable-action btn-default edit"
                    />
                  {{/if}}
                {{/if}}
              </div>
            {{/if}}
          {{/unless}}

          {{#if this.claimEnabled}}
            <div class="review-item__moderator-actions --extra">
              {{#if @reviewable.claimed_by}}
                <div class="review-item__assigned">
                  {{dIcon "user-plus"}}
                  <ReviewableCreatedBy
                    @showUsername={{true}}
                    @avatarSize="small"
                    @user={{@reviewable.claimed_by.user}}
                  />
                </div>
              {{/if}}
              <ReviewableClaimedTopic
                @topicId={{this.topicId}}
                @claimedBy={{@reviewable.claimed_by}}
                @onClaim={{this.claimedByChanged}}
              />
            </div>
          {{/if}}

          {{#if @showHelp}}
            <ReviewableHelpResources />
          {{/if}}
        </div>
      </div>
    </div>
  </template>
}
