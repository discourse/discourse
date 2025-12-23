/* eslint-disable ember/no-classic-components */
import { tracked } from "@glimmer/tracking";
import Component from "@ember/component";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action, computed,set } from "@ember/object";
import { alias } from "@ember/object/computed";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { classify, dasherize } from "@ember/string";
import { tagName } from "@ember-decorators/component";
import ScrubRejectedUserModal from "discourse/admin/components/modal/scrub-rejected-user";
import DButton from "discourse/components/d-button";
import HorizontalOverflowNav from "discourse/components/horizontal-overflow-nav";
import ExplainReviewableModal from "discourse/components/modal/explain-reviewable";
import RejectReasonReviewableModal from "discourse/components/modal/reject-reason-reviewable";
import ReviseAndRejectPostReviewable from "discourse/components/modal/revise-and-reject-post-reviewable";
import ReviewableBundledAction from "discourse/components/reviewable-bundled-action";
import ReviewableClaimedTopic from "discourse/components/reviewable-claimed-topic";
import ReviewableCreatedBy from "discourse/components/reviewable-created-by";
import ReviewableFlagReason from "discourse/components/reviewable-refresh/flag-reason";
import ReviewableHelpResources from "discourse/components/reviewable-refresh/help-resources";
import ReviewableInsights from "discourse/components/reviewable-refresh/insights";
import ReviewableTimeline from "discourse/components/reviewable-refresh/timeline";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import dasherizeHelper from "discourse/helpers/dasherize";
import editableValue from "discourse/helpers/editable-value";
import formatDate from "discourse/helpers/format-date";
import { newReviewableStatus } from "discourse/helpers/reviewable-status";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import { getAbsoluteURL } from "discourse/lib/get-url";
import optionalService from "discourse/lib/optional-service";
import { showAlert } from "discourse/lib/post-action-feedback";
import { clipboardCopy } from "discourse/lib/utilities";
import Category from "discourse/models/category";
import Composer from "discourse/models/composer";
import Topic from "discourse/models/topic";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

let _components = {};

const pluginReviewableParams = {};
const reviewableTypeLabels = {};

// The mappings defined here are default core mappings, and cannot be overridden
// by plugins.
const defaultActionModalClassMap = {
  revise_and_reject_post: ReviseAndRejectPostReviewable,
};
const actionModalClassMap = { ...defaultActionModalClassMap };

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
 * import { registerReviewableTypeLabel } from "discourse/components/reviewable-refresh/item";
 * registerReviewableTypeLabel("ReviewableAiPost", "discourse_ai.review.ai_post_flagged_as");
 */
export function registerReviewableTypeLabel(reviewableType, labelKey) {
  reviewableTypeLabels[reviewableType] = labelKey;
}

function lookupComponent(context, name) {
  return getOwner(context).resolveRegistration(`component:${name}`);
}

@tagName("")
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
  @tracked activeTab = "timeline";

  @alias("reviewable.claimed_by.automatic") autoClaimed;

  updating = null;
  editing = false;
  _updates = null;

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

  @computed(
    "reviewable.type",
    "reviewable.last_performing_username",
    "siteSettings.blur_tl0_flagged_posts_media",
    "reviewable.target_created_by_trust_level",
    "reviewable.deleted_at"
  )
  get customClasses(
    
  ) {
    let classes = dasherize(this.reviewable?.type);

    if (this.reviewable?.last_performing_username) {
      classes = `${classes} reviewable-stale`;
    }

    if (this.siteSettings?.blur_tl0_flagged_posts_media && this.reviewable?.target_created_by_trust_level === 0) {
      classes = `${classes} blur-images`;
    }

    if (this.reviewable?.deleted_at) {
      classes = `${classes} reviewable-deleted`;
    }

    return classes;
  }

  @computed(
    "reviewable.created_from_flag",
    "reviewable.status",
    "claimOptional",
    "claimRequired",
    "reviewable.claimed_by",
    "siteSettings.reviewable_old_moderator_actions"
  )
  get displayContextQuestion(
    
  ) {
    return (
      this.siteSettings?.reviewable_old_moderator_actions &&
      this.reviewable?.created_from_flag &&
      this.reviewable?.status === 0 &&
      (this.claimOptional || (this.claimRequired && this.reviewable?.claimed_by !== null))
    );
  }

  @computed(
    "reviewable.topic",
    "reviewable.topic_id",
    "reviewable.removed_topic_id"
  )
  get topicId() {
    return (this.reviewable?.topic && this.reviewable?.topic?.id) || this.reviewable?.topic_id || this.reviewable?.removed_topic_id;
  }

  @computed(
    "siteSettings.reviewable_claiming",
    "topicId",
    "reviewable.claimed_by.automatic",
    "reviewable.status"
  )
  get claimEnabled() {
    return (
      (this.siteSettings?.reviewable_claiming !== "disabled" || this.reviewable?.claimed_by?.automatic) && !!this.topicId && this.reviewable?.status === 0
    );
  }

  @computed("siteSettings.reviewable_claiming", "claimEnabled")
  get claimOptional() {
    return !this.claimEnabled || this.siteSettings?.reviewable_claiming === "optional";
  }

  @computed("siteSettings.reviewable_claiming", "claimEnabled")
  get claimRequired() {
    return this.claimEnabled && this.siteSettings?.reviewable_claiming === "required";
  }

  @computed(
    "claimEnabled",
    "siteSettings.reviewable_claiming",
    "reviewable.claimed_by",
    "reviewable.bundled_actions"
  )
  get canPerform() {
    if (this.reviewable?.bundled_actions?.length === 0) {
      return false;
    }
    if (!this.claimEnabled) {
      return true;
    }

    if (this.reviewable?.claimed_by) {
      return this.reviewable?.claimed_by?.user.id === this.currentUser.id;
    }

    return this.siteSettings?.reviewable_claiming !== "required";
  }

  @computed(
    "siteSettings.reviewable_claiming",
    "reviewable.claimed_by"
  )
  get claimHelp() {
    if (this.reviewable?.claimed_by) {
      if (this.reviewable?.claimed_by?.user.id === this.currentUser.id) {
        return i18n("review.claim_help.claimed_by_you");
      } else if (this.reviewable?.claimed_by?.automatic) {
        return i18n("review.claim_help.automatically_claimed_by", {
          username: this.reviewable?.claimed_by?.user.username,
        });
      } else {
        return i18n("review.claim_help.claimed_by_other", {
          username: this.reviewable?.claimed_by?.user.username,
        });
      }
    }

    return this.siteSettings?.reviewable_claiming === "optional"
      ? i18n("review.claim_help.optional")
      : i18n("review.claim_help.required");
  }

  // Find a component to render, if one exists. For example:
  // `ReviewableUser` will return `reviewable/user` or `reviewable-user`.
  // The former is the new reviewable component, so will only be returned if it exists.
  @computed("reviewable.type")
  get reviewableComponent() {
    if (_components[this.reviewable?.type] !== undefined) {
      return _components[this.reviewable?.type];
    }

    const owner = getOwner(this);
    const dasherized = dasherize(this.reviewable?.type);
    const componentNames = [
      dasherized.replace("reviewable-", "reviewable-refresh/"),
      dasherized,
    ];

    for (const componentName of componentNames) {
      const componentExists =
        owner.hasRegistration(`component:${componentName}`) ||
        owner.hasRegistration(`template:components/${componentName}`);
      if (componentExists) {
        _components[this.reviewable?.type] = componentName;
        break;
      }
    }
    return _components[this.reviewable?.type] || null;
  }

  @computed("_updates.category_id", "reviewable.category.id")
  get tagCategoryId() {
    return this._updates?.category_id || this.reviewable?.category?.id;
  }

  @computed("reviewable.reviewable_scores")
  get scoreSummary() {
    const scoreData = this.reviewable?.reviewable_scores?.reduce((acc, score) => {
      if (!acc[score.score_type.type]) {
        acc[score.score_type.type] = {
          title: score.score_type.title,
          type: score.score_type.type,
          count: 0,
        };
      }

      acc[score.score_type.type].count += 1;
      return acc;
    }, {});

    return Object.values(scoreData);
  }

  @computed(
    "reviewable.type",
    "reviewable.created_from_flag",
    "topicId"
  )
  get reviewableTypeLabel() {
    // handle plugin types
    if (reviewableTypeLabels[this.reviewable?.type]) {
      return reviewableTypeLabels[this.reviewable?.type];
    }

    // core types
    if (this.reviewable?.type === "ReviewableUser") {
      return "review.user_label";
    }

    if (this.reviewable?.type === "ReviewableQueuedPost") {
      // if topic_id is null it's a new topic
      return this.topicId ? "review.queued_post_label" : "review.queued_topic_label";
    }

    if (this.reviewable?.type === "ReviewableChatMessage") {
      return "review.chat_flagged_as";
    }

    if (this.reviewable?.created_from_flag) {
      return "review.post_flagged_as";
    }

    // fallback
    return "review.flagged_as";
  }

  @bind
  _updateClaimedBy(data) {
    if (data.topic_id !== this.reviewable.topic.id) {
      return;
    }

    const now = new Date().toISOString();

    const user = this.store.createRecord("user", data.user);
    if (data.claimed) {
      this.reviewable.set("claimed_by", { user, automatic: data.automatic });
      this.reviewable.set("reviewable_histories", [
        ...this.reviewable.reviewable_histories,
        {
          reviewable_history_type: 3,
          created_at: now,
          created_by: user,
        },
      ]);
    } else {
      this.reviewable.set("claimed_by", null);
      this.reviewable.set("reviewable_histories", [
        ...this.reviewable.reviewable_histories,
        {
          reviewable_history_type: 4,
          created_at: now,
          created_by: user,
        },
      ]);
    }
  }

  @bind
  _updateStatus(data) {
    if (data.remove_reviewable_ids.includes(this.reviewable.id)) {
      delete data.remove_reviewable_ids;
      this._performResult(data, {}, this.reviewable);
    }
  }

  @bind
  async _performConfirmed(performableAction, additionalData = {}) {
    let reviewable = this.reviewable;

    let performAction = async () => {
      this.disabled = true;

      let version = reviewable.get("version");
      this.set("updating", true);

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
        .catch(popupAjaxError)
        .finally(() => {
          this.set("updating", false);
          this.disabled = false;
        });
    };

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

    if (this.remove && result.remove_reviewable_ids) {
      this.remove(result.remove_reviewable_ids);
    } else {
      return this.store.find("reviewable", reviewable.id);
    }
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
    try {
      await ajax({
        url: `/review/${this.reviewable.id}/scrub`,
        type: "PUT",
        data: { reason },
      });
      this.store.find("reviewable", this.reviewable.id);
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

  _penalize(adminToolMethod, reviewable, performAction) {
    let adminTools = this.adminTools;
    if (adminTools) {
      let createdBy = reviewable.get("target_created_by");
      let postId = reviewable.get("post_id");
      let postEdit = reviewable.get("raw");

      return adminTools[adminToolMethod](createdBy, {
        postId,
        postEdit,
        before: performAction,
      });
    }
  }

  async #claimReviewable() {
    if (!this.reviewable.topic) {
      // We can't claim a reviewable without a topic, so treat it as claimed
      return true;
    }

    if (!this.reviewable.claimed_by) {
      const claim = this.store.createRecord("reviewable-claimed-topic");

      try {
        await claim.save({
          topic_id: this.reviewable.topic.id,
          automatic: true,
        });
        this.reviewable.set("claimed_by", {
          user: this.currentUser,
          automatic: true,
        });
      } catch (e) {
        popupAjaxError(e);
        return false;
      }
    }

    return this.reviewable.claimed_by?.user?.id === this.currentUser.id;
  }

  async #unclaimAutomaticReviewable() {
    if (!this.reviewable.topic || !this.reviewable.claimed_by?.automatic) {
      return;
    }

    try {
      await ajax(`/reviewable_claimed_topics/${this.reviewable.topic.id}`, {
        type: "DELETE",
        data: { automatic: true },
      });
      this.reviewable.set("claimed_by", null);
    } catch (e) {
      popupAjaxError(e);
    }
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
    this.activeTab = tabName;
  }

  @action
  edit() {
    this.set("editing", true);
    this.set("_updates", { payload: {} });
  }

  @action
  cancelEdit() {
    this.set("editing", false);
  }

  @action
  saveEdit() {
    let updates = this._updates;

    // Remove empty objects
    Object.keys(updates).forEach((name) => {
      let attr = updates[name];
      if (typeof attr === "object" && Object.keys(attr).length === 0) {
        delete updates[name];
      }
    });

    this.set("updating", true);
    return this.reviewable
      .update(updates)
      .then(() => this.set("editing", false))
      .catch(popupAjaxError)
      .finally(() => this.set("updating", false));
  }

  @action
  categoryChanged(categoryId) {
    let category = Category.findById(categoryId);

    if (!category) {
      category = Category.findUncategorized();
    }

    set(this._updates, "category_id", category.id);
  }

  @action
  valueChanged(fieldId, event) {
    set(this._updates, fieldId, event.target.value);
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
        this.dialog.confirm({
          message,
          didConfirm: () => this._performConfirmed(performableAction),
        });
      }
    } else if (actionModalClass) {
      if (await this.#claimReviewable()) {
        this.modal.show(actionModalClass, {
          model: {
            reviewable: this.reviewable,
            performConfirmed: this._performConfirmed,
            action: performableAction,
          },
        });
      }
    } else {
      return this._performConfirmed(performableAction);
    }
  }

  get permalink() {
    return getAbsoluteURL(`/review/${this.reviewable.id}`);
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
        this.reviewable.id,
        "reviewable-permalink-copy",
        "review.copy_link_feedback",
        { actionBtn: button }
      );
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error("Failed to copy to clipboard:", error);
    }
  }

  <template>
    <div class="review-container">

      <div
        data-reviewable-id={{this.reviewable.id}}
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
                {{icon "d-post-share"}}
              </button>

              {{newReviewableStatus
                this.reviewable.status
                this.reviewable.type
              }}

              <span class="reviewable-created-date">
                {{formatDate this.reviewable.created_at format="tiny"}}
              </span>

            </div>
            {{#if this.editing}}
              <div class="editable-fields">
                {{#each this.reviewable.editable_fields as |f|}}
                  <div class="editable-field {{dasherizeHelper f.id}}">
                    {{#let
                      (lookupComponent this (concat "reviewable-field-" f.type))
                      as |FieldComponent|
                    }}
                      <FieldComponent
                        @tagName=""
                        @value={{editableValue this.reviewable f.id}}
                        @tagCategoryId={{this.tagCategoryId}}
                        @valueChanged={{fn this.valueChanged f.id}}
                        @categoryChanged={{this.categoryChanged}}
                      />
                    {{/let}}
                  </div>
                {{/each}}
              </div>
            {{else}}

              {{#let
                (lookupComponent this this.reviewableComponent)
                as |ReviewableComponent|
              }}
                <ReviewableComponent
                  @reviewable={{this.reviewable}}
                  @tagName=""
                />
              {{/let}}
            {{/if}}
          </div>

          <div class="review-item__insights">
            <div class="d-nav-submenu">
              <HorizontalOverflowNav
                @ariaLabel="Review tabs"
                class="d-nav-submenu__tabs"
              >
                <li
                  class={{concatClass
                    "timeline"
                    (if (eq this.activeTab "timeline") "active")
                  }}
                >
                  <a
                    href="#"
                    class={{if (eq this.activeTab "timeline") "active"}}
                    {{on "click" (fn this.switchTab "timeline")}}
                  >
                    {{i18n "review.timeline_and_notes"}}
                  </a>
                </li>
                <li
                  class={{concatClass
                    "insights"
                    (if (eq this.activeTab "insights") "active")
                  }}
                >
                  <a
                    href="#"
                    class={{if (eq this.activeTab "insights") "active"}}
                    {{on "click" (fn this.switchTab "insights")}}
                  >
                    {{i18n "review.insights.title"}}
                  </a>
                </li>
              </HorizontalOverflowNav>
            </div>

            {{#if (eq this.activeTab "insights")}}
              <ReviewableInsights @reviewable={{this.reviewable}} />
            {{else if (eq this.activeTab "timeline")}}
              <ReviewableTimeline
                @reviewable={{this.reviewable}}
                @historyEvents={{this.reviewable.reviewable_histories}}
              />
            {{/if}}
          </div>
        </div>

        <div class="review-item__aside">

          {{#unless this.reviewable.last_performing_username}}
            {{#if this.canPerform}}
              <div class="review-item__moderator-actions">
                <h3 class="review-item__aside-title">
                  {{#if this.displayContextQuestion}}
                    {{this.reviewable.flaggedReviewableContextQuestion}}
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
                  {{#each this.reviewable.bundled_actions as |bundle|}}
                    <ReviewableBundledAction
                      @bundle={{bundle}}
                      @performAction={{this.perform}}
                      @reviewableUpdating={{this.disabled}}
                    />
                  {{/each}}

                  {{#if this.reviewable.can_edit}}
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
              {{#if this.reviewable.claimed_by}}
                <div class="review-item__assigned">
                  {{icon "user-plus"}}
                  <ReviewableCreatedBy
                    @showUsername={{true}}
                    @avatarSize="small"
                    @user={{this.reviewable.claimed_by.user}}
                  />
                </div>
              {{/if}}
              <ReviewableClaimedTopic
                @topicId={{this.topicId}}
                @claimedBy={{this.reviewable.claimed_by}}
                @onClaim={{fn (mut this.reviewable.claimed_by)}}
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
