import computed from "ember-addons/ember-computed-decorators";

export default Ember.Controller.extend({
  queryParams: ["min_score", "type", "status", "category_id", "topic_id"],
  type: null,
  status: "pending",
  min_score: null,
  category_id: null,
  reviewables: null,
  topic_id: null,
  filtersExpanded: false,

  init(...args) {
    this._super(...args);
    this.set("min_score", this.siteSettings.min_score_default_visibility);
    this.set("filtersExpanded", !this.site.mobileView);
  },

  @computed
  allTypes() {
    return ["flagged_post", "queued_post", "user"].map(type => {
      return {
        id: `Reviewable${type.classify()}`,
        name: I18n.t(`review.types.reviewable_${type}.title`)
      };
    });
  },

  @computed
  statuses() {
    return ["pending", "approved", "rejected", "ignored", "reviewed"].map(
      id => {
        return { id, name: I18n.t(`review.statuses.${id}.title`) };
      }
    );
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
        min_score: this.get("filterScore"),
        status: this.get("filterStatus"),
        category_id: this.get("filterCategoryId")
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
