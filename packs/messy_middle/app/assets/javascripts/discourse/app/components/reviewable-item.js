import Category from "discourse/models/category";
import Component from "@ember/component";
import I18n from "I18n";
import { ajax } from "discourse/lib/ajax";
import { classify, dasherize } from "@ember/string";
import discourseComputed, { bind } from "discourse-common/utils/decorators";
import optionalService from "discourse/lib/optional-service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { action, set } from "@ember/object";
import showModal from "discourse/lib/show-modal";
import { inject as service } from "@ember/service";
import { getOwner } from "discourse-common/lib/get-owner";

let _components = {};

const pluginReviewableParams = {};

export function addPluginReviewableParam(reviewableType, param) {
  pluginReviewableParams[reviewableType]
    ? pluginReviewableParams[reviewableType].push(param)
    : (pluginReviewableParams[reviewableType] = [param]);
}

export default Component.extend({
  adminTools: optionalService(),
  dialog: service(),
  tagName: "",
  updating: null,
  editing: false,
  _updates: null,

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
  },

  @discourseComputed(
    "reviewable.topic",
    "reviewable.topic_id",
    "reviewable.removed_topic_id"
  )
  topicId(topic, topicId, removedTopicId) {
    return (topic && topic.id) || topicId || removedTopicId;
  },

  @discourseComputed("siteSettings.reviewable_claiming", "topicId")
  claimEnabled(claimMode, topicId) {
    return claimMode !== "disabled" && !!topicId;
  },

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
  },

  @discourseComputed(
    "siteSettings.reviewable_claiming",
    "reviewable.claimed_by"
  )
  claimHelp(claimMode, claimedBy) {
    if (claimedBy) {
      return claimedBy.id === this.currentUser.id
        ? I18n.t("review.claim_help.claimed_by_you")
        : I18n.t("review.claim_help.claimed_by_other", {
            username: claimedBy.username,
          });
    }

    return claimMode === "optional"
      ? I18n.t("review.claim_help.optional")
      : I18n.t("review.claim_help.required");
  },

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
  },

  @discourseComputed("_updates.category_id", "reviewable.category.id")
  tagCategoryId(updatedCategoryId, categoryId) {
    return updatedCategoryId || categoryId;
  },

  @bind
  _performConfirmed(performableAction) {
    let reviewable = this.reviewable;

    let performAction = () => {
      let version = reviewable.get("version");
      this.set("updating", true);

      const data = {
        send_email: reviewable.sendEmail,
        reject_reason: reviewable.rejectReason,
      };

      (pluginReviewableParams[reviewable.type] || []).forEach((param) => {
        if (reviewable[param]) {
          data[param] = reviewable[param];
        }
      });

      return ajax(
        `/review/${reviewable.id}/perform/${performableAction.id}?version=${version}`,
        {
          type: "PUT",
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

          if (this.attrs.remove) {
            this.attrs.remove(performResult.remove_reviewable_ids);
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
  },

  clientSuspend(reviewable, performAction) {
    this._penalize("showSuspendModal", reviewable, performAction);
  },

  clientSilence(reviewable, performAction) {
    this._penalize("showSilenceModal", reviewable, performAction);
  },

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
  },

  @action
  explainReviewable(reviewable, event) {
    event?.preventDefault();
    showModal("explain-reviewable", {
      title: "review.explain.title",
      model: reviewable,
    });
  },

  actions: {
    edit() {
      this.set("editing", true);
      this.set("_updates", { payload: {} });
    },

    cancelEdit() {
      this.set("editing", false);
    },

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
    },

    categoryChanged(categoryId) {
      let category = Category.findById(categoryId);

      if (!category) {
        category = Category.findUncategorized();
      }

      set(this._updates, "category_id", category.id);
    },

    valueChanged(fieldId, event) {
      set(this._updates, fieldId, event.target.value);
    },

    perform(performableAction) {
      if (this.updating) {
        return;
      }

      const message = performableAction.get("confirm_message");
      let requireRejectReason = performableAction.get("require_reject_reason");
      let customModal = performableAction.get("custom_modal");
      if (message) {
        this.dialog.confirm({
          message,
          didConfirm: () => this._performConfirmed(performableAction),
        });
      } else if (requireRejectReason) {
        showModal("reject-reason-reviewable", {
          title: "review.reject_reason.title",
          model: this.reviewable,
        }).setProperties({
          performConfirmed: this._performConfirmed,
          action: performableAction,
        });
      } else if (customModal) {
        showModal(customModal, {
          title: `review.${customModal}.title`,
          model: this.reviewable,
        }).setProperties({
          performConfirmed: this._performConfirmed,
          action: performableAction,
        });
      } else {
        return this._performConfirmed(performableAction);
      }
    },
  },
});
