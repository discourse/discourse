import Controller from "@ember/controller";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { underscore } from "@ember/string";
import { isPresent } from "@ember/utils";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { REVIEWABLE_UNKNOWN_TYPE_SOURCE } from "discourse/lib/constants";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";

export default class ReviewIndexController extends Controller {
  @service currentUser;
  @service dialog;
  @service toasts;

  queryParams = [
    "priority",
    "type",
    "status",
    "category_id",
    "topic_id",
    "username",
    "reviewed_by",
    "from_date",
    "to_date",
    "sort_order",
    "additional_filters",
    "flagged_by",
    "score_type",
  ];

  type = null;
  status = "pending";
  priority = this.siteSettings.reviewable_default_visibility;
  category_id = null;
  reviewables = null;
  topic_id = null;
  filtersExpanded = this.site.desktopView;
  username = "";
  reviewed_by = "";
  flagged_by = "";
  from_date = null;
  to_date = null;
  sort_order = null;
  additional_filters = null;
  filterScoreType = null;
  unknownTypeSource = REVIEWABLE_UNKNOWN_TYPE_SOURCE;

  @discourseComputed("reviewableTypes")
  allTypes() {
    return (this.reviewableTypes || []).map((type) => {
      const translationKey = underscore(type).replace(/[^\w]+/g, "_");

      return {
        id: type,
        name: i18n(`review.types.${translationKey}.title`),
      };
    });
  }

  @discourseComputed("scoreTypes")
  allScoreTypes() {
    return this.scoreTypes || [];
  }

  @discourseComputed
  priorities() {
    return ["any", "low", "medium", "high"].map((priority) => {
      return {
        id: priority,
        name: i18n(`review.filters.priority.${priority}`),
      };
    });
  }

  @discourseComputed
  sortOrders() {
    return ["score", "score_asc", "created_at", "created_at_asc"].map(
      (order) => {
        return {
          id: order,
          name: i18n(`review.filters.orders.${order}`),
        };
      }
    );
  }

  @discourseComputed
  statuses() {
    return [
      "pending",
      "approved",
      "rejected",
      "deleted",
      "ignored",
      "reviewed",
      "all",
    ].map((id) => {
      return { id, name: i18n(`review.statuses.${id}.title`) };
    });
  }

  @discourseComputed("filtersExpanded")
  toggleFiltersIcon(filtersExpanded) {
    return filtersExpanded ? "chevron-up" : "chevron-down";
  }

  setRange(range) {
    this.setProperties(range);
  }

  refreshModel() {
    next(() => this.send("refreshRoute"));
  }

  @discourseComputed("unknownReviewableTypes")
  displayUnknownReviewableTypesWarning(unknownReviewableTypes) {
    return unknownReviewableTypes?.length > 0 && this.currentUser.admin;
  }

  @action
  remove(ids) {
    if (!ids) {
      return;
    }

    let newList = this.reviewables.reject((reviewable) => {
      return ids.includes(reviewable.id);
    });

    if (newList.length === 0) {
      this.refreshModel();
    } else {
      this.reviewables.setObjects(newList);
    }
  }

  @action
  resetTopic() {
    this.set("topic_id", null);
    this.refreshModel();
  }

  @action
  ignoreAllUnknownTypes() {
    return this.dialog.deleteConfirm({
      message: i18n("review.unknown.delete_confirm"),
      didConfirm: async () => {
        try {
          await ajax("/admin/unknown_reviewables/destroy", {
            type: "delete",
          });
          this.set("unknownReviewableTypes", []);
          this.toasts.success({
            data: { message: i18n("review.unknown.ignore_success") },
          });
        } catch (e) {
          popupAjaxError(e);
        }
      },
    });
  }

  @action
  refresh() {
    const currentStatus = this.status;
    const nextStatus = this.filterStatus;
    const currentOrder = this.sort_order;
    let nextOrder = this.filterSortOrder;

    const createdAtStatuses = ["reviewed", "all"];
    const priorityStatuses = [
      "approved",
      "rejected",
      "deleted",
      "ignored",
      "pending",
    ];

    if (
      createdAtStatuses.includes(currentStatus) &&
      currentOrder === "created_at" &&
      priorityStatuses.includes(nextStatus) &&
      nextOrder === "created_at"
    ) {
      nextOrder = "score";
    }

    if (
      priorityStatuses.includes(currentStatus) &&
      currentOrder === "score" &&
      createdAtStatuses.includes(nextStatus) &&
      nextOrder === "score"
    ) {
      nextOrder = "created_at";
    }

    this.setProperties({
      type: this.filterType,
      priority: this.filterPriority,
      status: this.filterStatus,
      category_id: this.filterCategoryId,
      username: this.filterUsername,
      reviewed_by: this.filterReviewedBy,
      flagged_by: this.filterFlaggedBy,
      score_type: this.filterScoreType,
      from_date: isPresent(this.filterFromDate)
        ? this.filterFromDate.toISOString(true).split("T")[0]
        : null,
      to_date: isPresent(this.filterToDate)
        ? this.filterToDate.toISOString(true).split("T")[0]
        : null,
      sort_order: nextOrder,
      additional_filters: JSON.stringify(this.additionalFilters),
    });

    this.refreshModel();
  }

  @action
  loadMore() {
    return this.reviewables.loadMore();
  }

  @action
  toggleFilters() {
    this.toggleProperty("filtersExpanded");
  }

  @action
  updateFilterReviewedBy(selected) {
    this.set("filterReviewedBy", selected.firstObject);
  }

  @action
  updateFilterFlaggedBy(selected) {
    this.set("filterFlaggedBy", selected.firstObject);
  }

  @action
  updateFilterUsername(selected) {
    this.set("filterUsername", selected.firstObject);
  }
}
