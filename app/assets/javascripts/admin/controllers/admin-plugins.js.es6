import computed from "ember-addons/ember-computed-decorators";

export default Ember.Controller.extend({
  @computed
  adminRoutes: function() {
    return this.get("model")
      .map(p => {
        if (p.get("enabled")) {
          return p.admin_route;
        }
      })
      .compact();
  },

  actions: {
    clearFilter() {
      this.setProperties({ filter: "", onlyOverridden: false });
    },

    toggleMenu() {
      $(".admin-detail").toggleClass("mobile-closed mobile-open");
    }
  }
});
