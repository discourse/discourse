export default Ember.Controller.extend({
  adminRoutes: function() {
    return this.get("model")
      .map(p => {
        if (p.get("enabled")) {
          return p.admin_route;
        }
      })
      .compact();
  }.property(),
  actions: {
    clearFilter() {
      this.setProperties({ filter: "", onlyOverridden: false });
    },

    toggleMenu() {
      $(".admin-detail").toggleClass("mobile-closed mobile-open");
    }
  }
});
