export default Discourse.Route.extend({
  renderTemplate() {
    this.render("user/messages");
  },

  model() {
    return this.modelFor("user");
  },

  actions: {
    willTransition: function() {
      this._super();
      this.controllerFor("user").set("pmView", null);
      return true;
    }
  }
});
