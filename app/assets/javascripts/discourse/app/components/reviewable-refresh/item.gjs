import { tracked } from "@glimmer/tracking";
import Component from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action, set } from "@ember/object";
import { alias } from "@ember/object/computed";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { classify, dasherize } from "@ember/string";
import { tagName } from "@ember-decorators/component";
import { eq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import HorizontalOverflowNav from "discourse/components/horizontal-overflow-nav";
import ExplainReviewableModal from "discourse/components/modal/explain-reviewable";
import RejectReasonReviewableModal from "discourse/components/modal/reject-reason-reviewable";
import ReviseAndRejectPostReviewable from "discourse/components/modal/revise-and-reject-post-reviewable";
import ReviewableBundledAction from "discourse/components/reviewable-bundled-action";
import ReviewableClaimedTopic from "discourse/components/reviewable-claimed-topic";
import ReviewableCreatedBy from "discourse/components/reviewable-created-by";
import ReviewableFlagReason from "discourse/components/reviewable-refresh/flag-reason";
import ReviewableInsights from "discourse/components/reviewable-refresh/insights";
import ReviewableTimeline from "discourse/components/reviewable-refresh/timeline";
import icon from "discourse/helpers/d-icon";
import { newReviewableStatus } from "discourse/helpers/reviewable-status";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseComputed, { bind } from "discourse/lib/decorators";
import optionalService from "discourse/lib/optional-service";
import Category from "discourse/models/category";
import Composer from "discourse/models/composer";
import Topic from "discourse/models/topic";
import { i18n } from "discourse-i18n";

// const IpLookup = optionalRequire("admin/components/ip-lookup");

let _components = {};

const pluginReviewableParams = {};

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

  @discourseComputed(
    "reviewable.type",
    "reviewable.last_performing_username",
    "siteSettings.blur_tl0_flagged_posts_media",
    "reviewable.target_created_by_trust_level",
    "reviewable.deleted_at"
  )
  customClasses(
    type,
    lastPerformingUsername,
    blurEnabled,
    trustLevel,
    deletedAt
  ) {
    let classes = dasherize(type);

    if (lastPerformingUsername) {
      classes = `${classes} reviewable-stale`;
    }

    if (blurEnabled && trustLevel === 0) {
      classes = `${classes} blur-images`;
    }

    if (deletedAt) {
      classes = `${classes} reviewable-deleted`;
    }

    return classes;
  }

  @discourseComputed(
    "reviewable.created_from_flag",
    "reviewable.status",
    "claimOptional",
    "claimRequired",
    "reviewable.claimed_by"
  )
  displayContextQuestion(
    createdFromFlag,
    status,
    claimOptional,
    claimRequired,
    claimedBy
  ) {
    return (
      createdFromFlag &&
      status === 0 &&
      (claimOptional || (claimRequired && claimedBy !== null))
    );
  }

  @discourseComputed(
    "reviewable.topic",
    "reviewable.topic_id",
    "reviewable.removed_topic_id"
  )
  topicId(topic, topicId, removedTopicId) {
    return (topic && topic.id) || topicId || removedTopicId;
  }

  @discourseComputed(
    "siteSettings.reviewable_claiming",
    "topicId",
    "reviewable.claimed_by.automatic"
  )
  claimEnabled(claimMode, topicId, autoClaimed) {
    return (claimMode !== "disabled" || autoClaimed) && !!topicId;
  }

  @discourseComputed("siteSettings.reviewable_claiming", "claimEnabled")
  claimOptional(claimMode, claimEnabled) {
    return !claimEnabled || claimMode === "optional";
  }

  @discourseComputed("siteSettings.reviewable_claiming", "claimEnabled")
  claimRequired(claimMode, claimEnabled) {
    return claimEnabled && claimMode === "required";
  }

  @discourseComputed(
    "claimEnabled",
    "siteSettings.reviewable_claiming",
    "reviewable.claimed_by"
  )
  canPerform(claimEnabled, claimMode, claimedBy) {
    if (!claimEnabled) {
      return true;
    }

    if (claimedBy) {
      return claimedBy.user.id === this.currentUser.id;
    }

    return claimMode !== "required";
  }

  @discourseComputed(
    "siteSettings.reviewable_claiming",
    "reviewable.claimed_by"
  )
  claimHelp(claimMode, claimedBy) {
    if (claimedBy) {
      if (claimedBy.user.id === this.currentUser.id) {
        return i18n("review.claim_help.claimed_by_you");
      } else if (claimedBy.automatic) {
        return i18n("review.claim_help.automatically_claimed_by", {
          username: claimedBy.user.username,
        });
      } else {
        return i18n("review.claim_help.claimed_by_other", {
          username: claimedBy.user.username,
        });
      }
    }

    return claimMode === "optional"
      ? i18n("review.claim_help.optional")
      : i18n("review.claim_help.required");
  }

  // Find a component to render, if one exists. For example:
  // `ReviewableUser` will return `reviewable/user` or `reviewable-user`.
  // The former is the new reviewable component, so will only be returned if it exists.
  @discourseComputed("reviewable.type")
  reviewableComponent(type) {
    if (_components[type] !== undefined) {
      return _components[type];
    }

    const owner = getOwner(this);
    const dasherized = dasherize(type);
    const componentNames = [
      dasherized.replace("reviewable-", "reviewable-refresh/"),
      dasherized,
    ];

    for (const componentName of componentNames) {
      const componentExists =
        owner.hasRegistration(`component:${componentName}`) ||
        owner.hasRegistration(`template:components/${componentName}`);
      if (componentExists) {
        _components[type] = componentName;
        break;
      }
    }
    return _components[type] || null;
  }

  @discourseComputed("_updates.category_id", "reviewable.category.id")
  tagCategoryId(updatedCategoryId, categoryId) {
    return updatedCategoryId || categoryId;
  }

  @discourseComputed("reviewable.type", "reviewable.target_created_by")
  showIpLookup(reviewableType) {
    return (
      reviewableType !== "ReviewableUser" &&
      this.currentUser.staff &&
      this.reviewable.target_created_by
    );
  }

  @discourseComputed("reviewable.reviewable_scores")
  scoreSummary(scores) {
    const scoreData = scores.reduce((acc, score) => {
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

  @bind
  _updateClaimedBy(data) {
    const user = data.user ? this.store.createRecord("user", data.user) : null;

    if (data.topic_id === this.reviewable.topic.id) {
      if (user) {
        this.reviewable.set("claimed_by", { user, automatic: data.automatic });
      } else {
        this.reviewable.set("claimed_by", null);
      }
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
                    "review.flagged_as"
                  }}</span>

                <div class="review-item__flag-badges">
                  {{#each this.scoreSummary as |score|}}
                    <ReviewableFlagReason @score={{score}} />
                  {{/each}}
                </div>
              </div>

              {{newReviewableStatus
                this.reviewable.status
                this.reviewable.type
              }}
            </div>

            {{#let
              (lookupComponent this this.reviewableComponent)
              as |ReviewableComponent|
            }}
              <ReviewableComponent
                @reviewable={{this.reviewable}}
                @tagName=""
              />
            {{/let}}
          </div>

          <div class="review-item__insights">
            <div class="d-nav-submenu">
              <HorizontalOverflowNav
                @ariaLabel="Review tabs"
                class="d-nav-submenu__tabs"
              >
                <li class={{if (eq this.activeTab "insights") "active"}}>
                  <a
                    href="#"
                    class={{if (eq this.activeTab "insights") "active"}}
                    {{on "click" (fn this.switchTab "insights")}}
                  >
                    {{i18n "review.insights.title"}}
                  </a>
                </li>
                <li class={{if (eq this.activeTab "timeline") "active"}}>
                  <a
                    href="#"
                    class={{if (eq this.activeTab "timeline") "active"}}
                    {{on "click" (fn this.switchTab "timeline")}}
                  >
                    {{i18n "review.timeline_and_notes"}}
                  </a>
                </li>
              </HorizontalOverflowNav>
            </div>

            {{#if (eq this.activeTab "insights")}}
              <ReviewableInsights @reviewable={{this.reviewable}} />
            {{else if (eq this.activeTab "timeline")}}
              <ReviewableTimeline @reviewable={{this.reviewable}} />
            {{/if}}
          </div>
        </div>

        <div class="review-item__aside">
          {{#if this.reviewable.claimed_by}}
            <div class="review-item__assigned">
              {{icon "user-plus"}}
              {{i18n "review.assigned_to"}}
              <ReviewableCreatedBy @user={{this.reviewable.claimed_by.user}} />
            </div>
          {{/if}}

          {{#unless this.reviewable.last_performing_username}}
            {{#if this.canPerform}}
              <div class="review-item__moderator-actions">
                <h3 class="review-item__aside-title">{{i18n
                    "review.moderator_actions"
                  }}</h3>
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
                      @icon="pencil"
                      @action={{this.edit}}
                      @label="review.edit"
                      class="reviewable-action btn-default edit"
                    />
                  {{/if}}
                {{/if}}
              </div>
            {{/if}}
          {{/unless}}

          <div class="review-item__moderator-actions --extra">
            {{#if this.claimEnabled}}
              <ReviewableClaimedTopic
                @topicId={{this.topicId}}
                @claimedBy={{this.reviewable.claimed_by}}
                @onClaim={{fn (mut this.reviewable.claimed_by)}}
              />
            {{/if}}
            <DButton
              @label="review.copy_link"
              @icon="link"
              class="btn-secondary"
            />
            <DButton
              @label="review.view_source"
              @icon="code"
              class="btn-secondary"
            />
          </div>

          <div class="review-item__resources">
            <h3 class="review-item__aside-title">{{i18n
                "review.need_help"
              }}</h3>
            <ul class="review-resources__list">
              <li class="review-resources__item">
                <span class="review-resources__icon">
                  {{icon "book"}}
                </span>
                <a
                  href={{this.siteSettings.moderation_guide_url}}
                  class="review-resources__link"
                >
                  {{i18n "review.help.moderation_guide"}}
                </a>
              </li>
              <li class="review-resources__item">
                <span class="review-resources__icon">
                  {{icon "book"}}
                </span>
                <a
                  href={{this.siteSettings.flag_priorities_url}}
                  class="review-resources__link"
                >
                  {{i18n "review.help.flag_priorities"}}
                </a>
              </li>
              <li class="review-resources__item">
                <span class="review-resources__icon">
                  {{icon "book"}}
                </span>
                <a
                  href={{this.siteSettings.spam_detection_url}}
                  class="review-resources__link"
                >
                  {{i18n "review.help.spam_detection"}}
                </a>
              </li>
            </ul>
          </div>
        </div>
      </div>
    </div>
  </template>
}
