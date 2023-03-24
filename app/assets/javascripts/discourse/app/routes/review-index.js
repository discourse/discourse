import DiscourseRoute from "discourse/routes/discourse";
import { isPresent } from "@ember/utils";
import { action } from "@ember/object";
import { bind } from "discourse-common/utils/decorators";

export default DiscourseRoute.extend({
  model(params) {
    if (params.sort_order === null) {
      if (params.status === "reviewed" || params.status === "all") {
        params.sort_order = "created_at";
      } else {
        params.sort_order = "score";
      }
    }

    return this.store.findAll("reviewable", params);
  },

  setupController(controller, model) {
    let meta = model.resultSetMeta;

    // "fast track" to update the current user's reviewable count before the message bus finds out.
    if (meta.reviewable_count !== undefined) {
      this.currentUser.set("reviewable_count", meta.reviewable_count);
    }
    if (meta.unseen_reviewable_count !== undefined) {
      this.currentUser.set(
        "unseen_reviewable_count",
        meta.unseen_reviewable_count
      );
    }

    controller.setProperties({
      reviewables: model,
      type: meta.type,
      filterType: meta.type,
      filterStatus: meta.status,
      filterTopic: meta.topic_id,
      filterCategoryId: meta.category_id,
      filterPriority: meta.priority,
      reviewableTypes: meta.reviewable_types,
      filterUsername: meta.username,
      filterReviewedBy: meta.reviewed_by,
      filterFromDate: isPresent(meta.from_date) ? moment(meta.from_date) : null,
      filterToDate: isPresent(meta.to_date) ? moment(meta.to_date) : null,
      filterSortOrder: meta.sort_order,
      sort_order: meta.sort_order,
      additionalFilters: meta.additional_filters || {},
    });

    controller.reviewables.setEach("last_performing_username", null);
  },

  activate() {
    this.messageBus.subscribe("/reviewable_claimed", this._updateClaimedBy);
    this.messageBus.subscribe(
      this._reviewableCountsChannel,
      this._updateReviewables
    );
  },

  deactivate() {
    this.messageBus.unsubscribe("/reviewable_claimed", this._updateClaimedBy);
    this.messageBus.unsubscribe(
      this._reviewableCountsChannel,
      this._updateReviewables
    );
  },

  @bind
  _updateClaimedBy(data) {
    const reviewables = this.controller.reviewables;
    if (reviewables) {
      const user = data.user
        ? this.store.createRecord("user", data.user)
        : null;
      reviewables.forEach((reviewable) => {
        if (data.topic_id === reviewable.topic.id) {
          reviewable.set("claimed_by", user);
        }
      });
    }
  },

  @bind
  _updateReviewables(data) {
    if (data.updates) {
      this.controller.reviewables.forEach((reviewable) => {
        const updates = data.updates[reviewable.id];
        if (updates) {
          reviewable.setProperties(updates);
        }
      });
    }
  },

  get _reviewableCountsChannel() {
    return this.currentUser.redesigned_user_menu_enabled
      ? `/reviewable_counts/${this.currentUser.id}`
      : "/reviewable_counts";
  },

  @action
  refreshRoute() {
    this.refresh();
  },
});
