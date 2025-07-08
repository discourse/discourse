import { tracked } from "@glimmer/tracking";
import Component from "@ember/component";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action, set } from "@ember/object";
import { alias } from "@ember/object/computed";
import { getOwner } from "@ember/owner";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { classify, dasherize } from "@ember/string";
import { tagName } from "@ember-decorators/component";
import DButton from "discourse/components/d-button";
import ExplainReviewableModal from "discourse/components/modal/explain-reviewable";
import RejectReasonReviewableModal from "discourse/components/modal/reject-reason-reviewable";
import ReviseAndRejectPostReviewable from "discourse/components/modal/revise-and-reject-post-reviewable";
import PluginOutlet from "discourse/components/plugin-outlet";
import ReviewableBundledAction from "discourse/components/reviewable-bundled-action";
import ReviewableClaimedTopic from "discourse/components/reviewable-claimed-topic";
import ReviewableCreatedByName from "discourse/components/reviewable-created-by-name";
import ageWithTooltip from "discourse/helpers/age-with-tooltip";
import avatar from "discourse/helpers/avatar";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import dasherizeHelper from "discourse/helpers/dasherize";
import editableValue from "discourse/helpers/editable-value";
import htmlSafe from "discourse/helpers/html-safe";
import lazyHash from "discourse/helpers/lazy-hash";
import reviewableStatus from "discourse/helpers/reviewable-status";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseComputed, { bind } from "discourse/lib/decorators";
import optionalService from "discourse/lib/optional-service";
import { optionalRequire } from "discourse/lib/utilities";
import Category from "discourse/models/category";
import Composer from "discourse/models/composer";
import Topic from "discourse/models/topic";
import { i18n } from "discourse-i18n";
import ReviewableScores from "./reviewable-scores";

const IpLookup = optionalRequire("admin/components/ip-lookup");

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
  @optionalService adminTools;

  @tracked disabled = false;

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
  // `ReviewableUser` will return `reviewable-user`
  @discourseComputed("reviewable.type")
  reviewableComponent(type) {
    if (_components[type] !== undefined) {
      return _components[type];
    }

    const dasherized = dasherize(type);
    const owner = getOwner(this);
    const componentExists =
      owner.hasRegistration(`component:${dasherized}`) ||
      owner.hasRegistration(`template:components/${dasherized}`);
    _components[type] = componentExists ? dasherized : null;
    return _components[type];
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
          didCancel: () => this.#unclaimAutomaticReviewable(),
        });
      }
    } else if (actionModalClass) {
      if (await this.#claimReviewable()) {
        await this.modal.show(actionModalClass, {
          model: {
            reviewable: this.reviewable,
            performConfirmed: this._performConfirmed,
            action: performableAction,
          },
        });
        await this.#unclaimAutomaticReviewable();
      }
    } else {
      return this._performConfirmed(performableAction);
    }
  }

  <template>
    <div
      data-reviewable-id={{this.reviewable.id}}
      class="reviewable-item {{this.customClasses}}"
    >
      <div class="reviewable-meta-data">
        <span
          class={{concatClass
            "reviewable-type"
            this.reviewable.humanTypeCssClass
          }}
        >{{this.reviewable.humanType}}</span>
        {{#if this.reviewable.reply_count}}
          <span class="reply-count">{{i18n
              "review.replies"
              count=this.reviewable.reply_count
            }}</span>
        {{/if}}
        <span class="created-at">
          <LinkTo
            @route="review.show"
            @model={{this.reviewable.id}}
          >{{ageWithTooltip this.reviewable.created_at}}</LinkTo>
        </span>
        <span class="status">
          {{reviewableStatus this.reviewable.status this.reviewable.type}}
        </span>
        <a
          href
          {{on "click" (fn this.explainReviewable this.reviewable)}}
          title={{i18n "review.explain.why"}}
          class="explain"
        >
          {{icon "circle-question"}}
        </a>
      </div>

      <div class="reviewable-contents">
        {{#if this.editing}}
          <div class="editable-fields">
            {{#if this.reviewable.created_by}}
              <div class="editable-created-by">
                {{avatar this.reviewable.created_by imageSize="tiny"}}
                <ReviewableCreatedByName @user={{this.reviewable.created_by}} />
              </div>
            {{/if}}

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
            <ReviewableComponent @reviewable={{this.reviewable}} @tagName="">
              <ReviewableScores @reviewable={{this.reviewable}} @tagName="" />
            </ReviewableComponent>
          {{/let}}
        {{/if}}
      </div>

      {{#if this.displayContextQuestion}}
        <h3 class="reviewable-item__context-question">
          {{this.reviewable.flaggedReviewableContextQuestion}}
        </h3>
      {{/if}}

      <div class="reviewable-actions">
        {{#unless this.reviewable.last_performing_username}}
          {{#if this.canPerform}}
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
          {{/if}}
        {{/unless}}

        {{#if this.reviewable.last_performing_username}}
          <div class="stale-help">{{htmlSafe
              (i18n
                "review.stale_help"
                username=this.reviewable.last_performing_username
              )
            }}</div>
        {{else}}
          {{#if this.claimEnabled}}
            <div class="claimed-actions">
              <span class="help">{{htmlSafe this.claimHelp}}</span>
              {{#unless this.autoClaimed}}
                <ReviewableClaimedTopic
                  @topicId={{this.topicId}}
                  @claimedBy={{this.reviewable.claimed_by}}
                  @onClaim={{fn (mut this.reviewable.claimed_by)}}
                />
              {{/unless}}
            </div>
          {{/if}}
        {{/if}}

        {{#if this.showIpLookup}}
          <IpLookup
            @ip="adminLookup"
            @userId={{this.reviewable.target_created_by.id}}
          />
        {{/if}}

        <PluginOutlet
          @name="reviewable-item-actions"
          @connectorTagName="div"
          @outletArgs={{lazyHash reviewable=this.reviewable}}
        />
      </div>
    </div>
  </template>
}
