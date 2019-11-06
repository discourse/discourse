import Controller from "@ember/controller";
import computed from "ember-addons/ember-computed-decorators";

export default Controller.extend({
  queryParams: [
    "priority",
    "type",
    "status",
    "category_id",
    "topic_id",
    "username",
    "sort_order"
  ],
  type: null,
  status: "pending",
  priority: "low",
  category_id: null,
  reviewables: null,
  topic_id: null,
  filtersExpanded: false,
  username: "",
  sort_order: "priority",

  init(...args) {
    this._super(...args);
    this.set("priority", this.siteSettings.reviewable_default_visibility);
    this.set("filtersExpanded", !this.site.mobileView);
  },

  @computed("reviewableTypes")
  allTypes() {
    return (this.reviewableTypes || []).map(type => {
      return {
        id: type,
        name: I18n.t(`review.types.${type.underscore()}.title`)
      };
    });
  },

  @computed
  priorities() {
    return ["low", "medium", "high"].map(priority => {
      return {
        id: priority,
        name: I18n.t(`review.filters.priority.${priority}`)
      };
    });
  },

  @computed
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

  @computed
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

  @computed("filtersExpanded")
  toggleFiltersIcon(filtersExpanded) {
    return filtersExpanded ? "chevron-up" : "chevron-down";
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
        sort_order: this.filterSortOrder
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
