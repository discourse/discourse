import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  queryParams: {
    order: { refreshModel: true },
    ascending: { refreshModel: true }
  },

  // TODO: this has been introduced to fix a bug in admin-users-list-show
  // loading AdminUser model multiple times without refactoring the controller
  beforeModel(transition) {
    const routeName = "adminUsersList.show";

    if (transition.targetName === routeName) {
      const params = transition.routeInfos.find(a => a.name === routeName)
        .params;
      const controller = this.controllerFor(routeName);
      if (controller) {
        controller.setProperties({
          order: transition.to.queryParams.order,
          ascending: transition.to.queryParams.ascending,
          query: params.filter,
          refreshing: false
        });

        controller.resetFilters();
      }
    }
  }
});
