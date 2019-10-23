import Component from "@ember/component";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import computed from "ember-addons/ember-computed-decorators";
import Category from "discourse/models/category";
import optionalService from "discourse/lib/optional-service";
import showModal from "discourse/lib/show-modal";

let _components = {};

export default Component.extend({
  adminTools: optionalService(),
  tagName: "",
  updating: null,
  editing: false,
  _updates: null,

  @computed("reviewable.type")
  customClass(type) {
    return type.dasherize();
  },

  @computed("siteSettings.reviewable_claiming", "reviewable.topic")
  claimEnabled(claimMode, topic) {
    return claimMode !== "disabled" && !!topic;
  },

  @computed(
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

  @computed("siteSettings.reviewable_claiming", "reviewable.claimed_by")
  claimHelp(claimMode, claimedBy) {
    if (claimedBy) {
      return claimedBy.id === this.currentUser.id
        ? I18n.t("review.claim_help.claimed_by_you")
        : I18n.t("review.claim_help.claimed_by_other", {
            username: claimedBy.username
          });
    }

    return claimMode === "optional"
      ? I18n.t("review.claim_help.optional")
      : I18n.t("review.claim_help.required");
  },

  // Find a component to render, if one exists. For example:
  // `ReviewableUser` will return `reviewable-user`
  @computed("reviewable.type")
  reviewableComponent(type) {
    if (_components[type] !== undefined) {
      return _components[type];
    }

    let dasherized = Ember.String.dasherize(type);
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
      return ajax(
        `/review/${reviewable.id}/perform/${action.id}?version=${version}`,
        {
          method: "PUT"
        }
      )
        .then(result => {
          let performResult = result.reviewable_perform_result;

          // "fast track" to update the current user's reviewable count before the message bus finds out.
          if (performResult.reviewable_count !== undefined) {
            this.currentUser.set("reviewable_count", result.reviewable_count);
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
      return;
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
        before: performAction
      });
    }
  },

  actions: {
    explainReviewable(reviewable) {
      showModal("explain-reviewable", {
        title: "review.explain.title",
        model: reviewable
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
      Object.keys(updates).forEach(name => {
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

    categoryChanged(category) {
      if (!category) {
        category = Category.findUncategorized();
      }
      this._updates.category_id = category.id;
    },

    valueChanged(fieldId, event) {
      Ember.set(this._updates, fieldId, event.target.value);
    },

    perform(action) {
      if (this.updating) {
        return;
      }

      let msg = action.get("confirm_message");
      if (msg) {
        bootbox.confirm(msg, answer => {
          if (answer) {
            return this._performConfirmed(action);
          }
        });
      } else {
        return this._performConfirmed(action);
      }
    }
  }
});
