import computed from "ember-addons/ember-computed-decorators";

export default Ember.Controller.extend({
  queryParams: [
    "priority",
    "type",
    "status",
    "category_id",
    "topic_id",
    "username"
  ],
  type: null,
  status: "pending",
  priority: "low",
  category_id: null,
  reviewables: null,
  topic_id: null,
  filtersExpanded: false,
  username: "",

  init(...args) {
    this._super(...args);
    this.set("priority", this.siteSettings.reviewable_default_visibility);
    this.set("filtersExpanded", !this.site.mobileView);
  },

  @computed("reviewableTypes")
  allTypes() {
    return (this.get("reviewableTypes") || []).map(type => {
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
  statuses() {
    return [
      "pending",
      "approved",
      "rejected",
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

      let newList = this.get("reviewables").reject(reviewable => {
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
        type: this.get("filterType"),
        priority: this.get("filterPriority"),
        status: this.get("filterStatus"),
        category_id: this.get("filterCategoryId"),
        username: this.get("filterUsername")
      });
      this.send("refreshRoute");
    },

    loadMore() {
      return this.get("reviewables").loadMore();
    },

    toggleFilters() {
      this.toggleProperty("filtersExpanded");
    }
  }
});
