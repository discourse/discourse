import LoadMore from "discourse/mixins/load-more";

export default Ember.View.extend(LoadMore, {
  loading: false,
  eyelineSelector: ".user-stream .item",
  classNames: ["user-stream"],

  actions: {
    loadMore: function() {
      var self = this;
      if (this.get("loading")) { return; }

      var postsStream = this.get("controller.model");
      postsStream.findItems().then(function () {
        self.set("loading", false);
        self.get("eyeline").flushRest();
      }).catch(function () { });
    }
  }
});
