export default Discourse.Route.extend({
  queryParams: {
    order: { refreshModel: true },
    ascending: { refreshModel: true }
  },

  beforeModel(transition) {
    const routeName = "adminUsersList.show";

    if (transition.targetName === routeName) {
      const params = transition.params[routeName];
      const controller = this.controllerFor(routeName);
      if (controller) {
        controller.setProperties({
          order: transition.queryParams.order,
          ascending: transition.queryParams.ascending,
          query: params.filter,
          showEmails: false,
          refreshing: false
        });

        controller._refreshUsers();
      }
    }
  }
});
