import Controller from "@ember/controller";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { underscore } from "@ember/string";
import { isPresent } from "@ember/utils";
import discourseComputed from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";

export default class ReviewIndexController extends Controller {
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
  from_date = null;
  to_date = null;
  sort_order = null;
  additional_filters = null;

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
  updateFilterUsername(selected) {
    this.set("filterUsername", selected.firstObject);
  }
}
