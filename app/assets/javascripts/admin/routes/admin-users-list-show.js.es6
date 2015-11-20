export default Discourse.Route.extend({
  model: function(params) {
    this.userFilter = params.filter;
    return Discourse.AdminUser.findAll(params.filter);
  },

  setupController: function(controller, model) {
    controller.setProperties({
      model: model,
      query: this.userFilter,
      showEmails: false,
      refreshing: false,
    });
  }
});
