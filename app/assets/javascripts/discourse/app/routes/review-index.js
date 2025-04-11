import { action } from "@ember/object";
import { isPresent } from "@ember/utils";
import { bind } from "discourse/lib/decorators";
import DiscourseRoute from "discourse/routes/discourse";

export default class ReviewIndex extends DiscourseRoute {
  model(params) {
    if (params.sort_order === null) {
      if (params.status === "reviewed" || params.status === "all") {
        params.sort_order = "created_at";
      } else {
        params.sort_order = "score";
      }
    }

    return this.store.findAll("reviewable", params);
  }

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
      unknownReviewableTypes: meta.unknown_reviewable_types_and_sources,
      scoreTypes: meta.score_types,
      filterUsername: meta.username,
      filterReviewedBy: meta.reviewed_by,
      filterFlaggedBy: meta.flagged_by,
      filterFromDate: isPresent(meta.from_date) ? moment(meta.from_date) : null,
      filterToDate: isPresent(meta.to_date) ? moment(meta.to_date) : null,
      filterSortOrder: meta.sort_order,
      sort_order: meta.sort_order,
      additionalFilters: meta.additional_filters || {},
    });

    controller.reviewables.setEach("last_performing_username", null);
  }

  activate() {
    this.messageBus.subscribe(
      this._reviewableCountsChannel,
      this._updateReviewables
    );
  }

  deactivate() {
    this.messageBus.unsubscribe(
      this._reviewableCountsChannel,
      this._updateReviewables
    );
  }

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
  }

  get _reviewableCountsChannel() {
    return `/reviewable_counts/${this.currentUser.id}`;
  }

  @action
  refreshRoute() {
    this.refresh();
  }
}
