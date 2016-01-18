import LoadMore from "discourse/mixins/load-more";

export default Ember.View.extend(LoadMore, {
  loading: false,
  eyelineSelector: ".email-list tr",

  actions: {
    loadMore() {
      if (this.get("loading") || this.get("model.allLoaded")) { return; }
      this.set("loading", true);
      return this.get("controller").loadMore().then(() => this.set("loading", false));
    }
  }
});
