import Controller from "@ember/controller";
import I18n from "I18n";
import discourseComputed from "discourse-common/utils/decorators";
import { isPresent } from "@ember/utils";
import { next } from "@ember/runloop";

export default Controller.extend({
  queryParams: [
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
  ],
  type: null,
  status: "pending",
  priority: "low",
  category_id: null,
  reviewables: null,
  topic_id: null,
  filtersExpanded: false,
  username: "",
  reviewed_by: "",
  from_date: null,
  to_date: null,
  sort_order: null,
  additional_filters: null,

  init(...args) {
    this._super(...args);
    this.set("priority", this.siteSettings.reviewable_default_visibility);
    this.set("filtersExpanded", !this.site.mobileView);
  },

  @discourseComputed("reviewableTypes")
  allTypes() {
    return (this.reviewableTypes || []).map((type) => {
      return {
        id: type,
        name: I18n.t(`review.types.${type.underscore()}.title`),
      };
    });
  },

  @discourseComputed
  priorities() {
    return ["any", "low", "medium", "high"].map((priority) => {
      return {
        id: priority,
        name: I18n.t(`review.filters.priority.${priority}`),
      };
    });
  },

  @discourseComputed
  sortOrders() {
    return ["score", "score_asc", "created_at", "created_at_asc"].map(
      (order) => {
        return {
          id: order,
          name: I18n.t(`review.filters.orders.${order}`),
        };
      }
    );
  },

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
      return { id, name: I18n.t(`review.statuses.${id}.title`) };
    });
  },

  @discourseComputed("filtersExpanded")
  toggleFiltersIcon(filtersExpanded) {
    return filtersExpanded ? "chevron-up" : "chevron-down";
  },

  setRange(range) {
    this.setProperties(range);
  },

  refreshModel() {
    next(() => this.send("refreshRoute"));
  },

  actions: {
    remove(ids) {
      if (!ids) {
        return;
      }

      let newList = this.reviewables.reject((reviewable) => {
        return ids.indexOf(reviewable.id) !== -1;
      });

      if (newList.length === 0) {
        this.refreshModel();
      } else {
        this.set("reviewables", newList);
      }
    },

    resetTopic() {
      this.set("topic_id", null);
      this.refreshModel();
    },

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
    },

    loadMore() {
      return this.reviewables.loadMore();
    },

    toggleFilters() {
      this.toggleProperty("filtersExpanded");
    },

    updateFilterReviewedBy(selected) {
      this.set("filterReviewedBy", selected.firstObject);
    },

    updateFilterUsername(selected) {
      this.set("filterUsername", selected.firstObject);
    },
  },
});
