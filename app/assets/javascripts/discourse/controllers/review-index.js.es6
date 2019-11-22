import discourseComputed from "discourse-common/utils/decorators";
import Controller from "@ember/controller";

export default Controller.extend({
  queryParams: [
    "priority",
    "type",
    "status",
    "category_id",
    "topic_id",
    "username",
    "from_date",
    "to_date",
    "sort_order",
    "additional_filters"
  ],
  type: null,
  status: "pending",
  priority: "low",
  category_id: null,
  reviewables: null,
  topic_id: null,
  filtersExpanded: false,
  username: "",
  from_date: null,
  to_date: null,
  sort_order: "priority",
  additional_filters: null,

  init(...args) {
    this._super(...args);
    this.set("priority", this.siteSettings.reviewable_default_visibility);
    this.set("filtersExpanded", !this.site.mobileView);
  },

  @discourseComputed("reviewableTypes")
  allTypes() {
    return (this.reviewableTypes || []).map(type => {
      return {
        id: type,
        name: I18n.t(`review.types.${type.underscore()}.title`)
      };
    });
  },

  @discourseComputed
  priorities() {
    return ["low", "medium", "high"].map(priority => {
      return {
        id: priority,
        name: I18n.t(`review.filters.priority.${priority}`)
      };
    });
  },

  @discourseComputed
  sortOrders() {
    return ["priority", "priority_asc", "created_at", "created_at_asc"].map(
      order => {
        return {
          id: order,
          name: I18n.t(`review.filters.orders.${order}`)
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
      "all"
    ].map(id => {
      return { id, name: I18n.t(`review.statuses.${id}.title`) };
    });
  },

  @discourseComputed("filtersExpanded")
  toggleFiltersIcon(filtersExpanded) {
    return filtersExpanded ? "chevron-up" : "chevron-down";
  },

  setRange(range) {
    if (range.from) {
      this.set("from", new Date(range.from).toISOString().split("T")[0]);
    }
    if (range.to) {
      this.set("to", new Date(range.to).toISOString().split("T")[0]);
    }
  },

  actions: {
    remove(ids) {
      if (!ids) {
        return;
      }

      let newList = this.reviewables.reject(reviewable => {
        return ids.indexOf(reviewable.id) !== -1;
      });
      this.set("reviewables", newList);
    },

    resetTopic() {
      this.set("topic_id", null);
      this.send("refreshRoute");
    },

    refresh() {
      this.setProperties({
        type: this.filterType,
        priority: this.filterPriority,
        status: this.filterStatus,
        category_id: this.filterCategoryId,
        username: this.filterUsername,
        from_date: this.filterFromDate,
        to_date: this.filterToDate,
        sort_order: this.filterSortOrder,
        additional_filters: JSON.stringify(this.additionalFilters)
      });

      this.send("refreshRoute");
    },

    loadMore() {
      return this.reviewables.loadMore();
    },

    toggleFilters() {
      this.toggleProperty("filtersExpanded");
    }
  }
});
