Discourse.AdminFlagsView = Discourse.View.extend(Discourse.LoadMore, {
  loading: false,
  eyelineSelector: '.admin-flags tbody tr',
  loadMore: function() {
    var view = this;
    if(this.get("loading") || this.get("model.allLoaded")) { return; }
    this.set("loading", true);
    this.get("controller").loadMore().then(function(){
      view.set("loading", false);
    });
  }

});
