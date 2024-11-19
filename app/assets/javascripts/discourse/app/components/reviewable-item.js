import Component from "@ember/component";
import { action, set } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { classify, dasherize } from "@ember/string";
import { tagName } from "@ember-decorators/component";
import ExplainReviewableModal from "discourse/components/modal/explain-reviewable";
import RejectReasonReviewableModal from "discourse/components/modal/reject-reason-reviewable";
import ReviseAndRejectPostReviewable from "discourse/components/modal/revise-and-reject-post-reviewable";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import optionalService from "discourse/lib/optional-service";
import Category from "discourse/models/category";
import Composer from "discourse/models/composer";
import Topic from "discourse/models/topic";
import discourseComputed, { bind } from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";

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

@tagName("")
export default class ReviewableItem extends Component {
  @service dialog;
  @service modal;
  @service siteSettings;
  @service currentUser;
  @service composer;
  @optionalService adminTools;

  updating = null;
  editing = false;
  _updates = null;

  @discourseComputed(
    "reviewable.type",
    "reviewable.last_performing_username",
    "siteSettings.blur_tl0_flagged_posts_media",
    "reviewable.target_created_by_trust_level"
  )
  customClasses(type, lastPerformingUsername, blurEnabled, trustLevel) {
    let classes = dasherize(type);

    if (lastPerformingUsername) {
      classes = `${classes} reviewable-stale`;
    }

    if (blurEnabled && trustLevel === 0) {
      classes = `${classes} blur-images`;
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

  @discourseComputed("siteSettings.reviewable_claiming", "topicId")
  claimEnabled(claimMode, topicId) {
    return claimMode !== "disabled" && !!topicId;
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
      return claimedBy.id === this.currentUser.id;
    }

    return claimMode !== "required";
  }

  @discourseComputed(
    "siteSettings.reviewable_claiming",
    "reviewable.claimed_by"
  )
  claimHelp(claimMode, claimedBy) {
    if (claimedBy) {
      return claimedBy.id === this.currentUser.id
        ? i18n("review.claim_help.claimed_by_you")
        : i18n("review.claim_help.claimed_by_other", {
            username: claimedBy.username,
          });
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

  @bind
  _performConfirmed(performableAction, additionalData = {}) {
    let reviewable = this.reviewable;

    let performAction = () => {
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
        .then((result) => {
          let performResult = result.reviewable_perform_result;

          // "fast track" to update the current user's reviewable count before the message bus finds out.
          if (performResult.reviewable_count !== undefined) {
            this.currentUser.updateReviewableCount(
              performResult.reviewable_count
            );
          }

          if (performResult.unseen_reviewable_count !== undefined) {
            this.currentUser.set(
              "unseen_reviewable_count",
              performResult.unseen_reviewable_count
            );
          }

          if (this.remove) {
            this.remove(performResult.remove_reviewable_ids);
          } else {
            return this.store.find("reviewable", reviewable.id);
          }
        })
        .catch(popupAjaxError)
        .finally(() => this.set("updating", false));
    };

    if (performableAction.client_action) {
      let actionMethod =
        this[`client${classify(performableAction.client_action)}`];
      if (actionMethod) {
        return actionMethod.call(this, reviewable, performAction);
      } else {
        // eslint-disable-next-line no-console
        console.error(
          `No handler for ${performableAction.client_action} found`
        );
        return;
      }
    } else {
      return performAction();
    }
  }

  clientSuspend(reviewable, performAction) {
    this._penalize("showSuspendModal", reviewable, performAction);
  }

  clientSilence(reviewable, performAction) {
    this._penalize("showSilenceModal", reviewable, performAction);
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
      skipDraftCheck: true,
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
  perform(performableAction) {
    if (this.updating) {
      return;
    }

    const message = performableAction.get("confirm_message");
    const requireRejectReason = performableAction.get("require_reject_reason");
    const actionModalClass = requireRejectReason
      ? RejectReasonReviewableModal
      : actionModalClassMap[performableAction.server_action];

    if (message) {
      this.dialog.confirm({
        message,
        didConfirm: () => this._performConfirmed(performableAction),
      });
    } else if (actionModalClass) {
      this.modal.show(actionModalClass, {
        model: {
          reviewable: this.reviewable,
          performConfirmed: this._performConfirmed,
          action: performableAction,
        },
      });
    } else {
      return this._performConfirmed(performableAction);
    }
  }
}
