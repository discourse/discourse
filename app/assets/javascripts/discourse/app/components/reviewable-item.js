import Category from "discourse/models/category";
import Component from "@ember/component";
import I18n from "I18n";
import { ajax } from "discourse/lib/ajax";
import bootbox from "bootbox";
import { dasherize } from "@ember/string";
import discourseComputed from "discourse-common/utils/decorators";
import optionalService from "discourse/lib/optional-service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { set } from "@ember/object";
import showModal from "discourse/lib/show-modal";

let _components = {};

const pluginReviewableParams = {};

export function addPluginReviewableParam(reviewableType, param) {
  pluginReviewableParams[reviewableType]
    ? pluginReviewableParams[reviewableType].push(param)
    : (pluginReviewableParams[reviewableType] = [param]);
}

export default Component.extend({
  adminTools: optionalService(),
  tagName: "",
  updating: null,
  editing: false,
  _updates: null,

  @discourseComputed(
    "reviewable.type",
    "reviewable.stale",
    "siteSettings.blur_tl0_flagged_posts_media",
    "reviewable.target_created_by_trust_level"
  )
  customClasses(type, stale, blurEnabled, trustLevel) {
    let classes = type.dasherize();

    if (stale) {
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

    let dasherized = dasherize(type);
    let templatePath = `components/${dasherized}`;
    let template =
      Ember.TEMPLATES[`${templatePath}`] ||
      Ember.TEMPLATES[`javascripts/${templatePath}`];
    _components[type] = template ? dasherized : null;
    return _components[type];
  },

  _performConfirmed(action) {
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
        `/review/${reviewable.id}/perform/${action.id}?version=${version}`,
        {
          type: "PUT",
          data,
        }
      )
        .then((result) => {
          let performResult = result.reviewable_perform_result;

          // "fast track" to update the current user's reviewable count before the message bus finds out.
          if (performResult.reviewable_count !== undefined) {
            this.currentUser.set(
              "reviewable_count",
              performResult.reviewable_count
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

    if (action.client_action) {
      let actionMethod = this[`client${action.client_action.classify()}`];
      if (actionMethod) {
        return actionMethod.call(this, reviewable, performAction);
      } else {
        // eslint-disable-next-line no-console
        console.error(`No handler for ${action.client_action} found`);
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

  actions: {
    explainReviewable(reviewable) {
      showModal("explain-reviewable", {
        title: "review.explain.title",
        model: reviewable,
      });
    },

    edit() {
      this.set("editing", true);
      this._updates = { payload: {} };
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

      this._updates.category_id = category.id;
    },

    valueChanged(fieldId, event) {
      set(this._updates, fieldId, event.target.value);
    },

    perform(action) {
      if (this.updating) {
        return;
      }

      let msg = action.get("confirm_message");
      let requireRejectReason = action.get("require_reject_reason");
      let customModal = action.get("custom_modal");
      if (msg) {
        bootbox.confirm(msg, (answer) => {
          if (answer) {
            return this._performConfirmed(action);
          }
        });
      } else if (requireRejectReason) {
        showModal("reject-reason-reviewable", {
          title: "review.reject_reason.title",
          model: this.reviewable,
        }).setProperties({
          performConfirmed: this._performConfirmed.bind(this),
          action,
        });
      } else if (customModal) {
        showModal(customModal, {
          title: `review.${customModal}.title`,
          model: this.reviewable,
        }).setProperties({
          performConfirmed: this._performConfirmed.bind(this),
          action,
        });
      } else {
        return this._performConfirmed(action);
      }
    },
  },
});
