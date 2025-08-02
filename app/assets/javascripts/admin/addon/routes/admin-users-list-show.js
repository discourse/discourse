import DiscourseRoute from "discourse/routes/discourse";

export default class AdminUsersListShowRoute extends DiscourseRoute {
  queryParams = {
    order: { refreshModel: true },
    asc: { refreshModel: true },
    username: { refreshModel: true },
  };

  // TODO: this has been introduced to fix a bug in admin-users-list-show
  // loading AdminUser model multiple times without refactoring the controller
  beforeModel(transition) {
    const routeName = "adminUsersList.show";

    if (transition.targetName === routeName) {
      const params = transition.routeInfos.find(
        (a) => a.name === routeName
      ).params;
      const controller = this.controllerFor(routeName);
      if (controller) {
        controller.setProperties({
          order: transition.to.queryParams.order,
          asc: transition.to.queryParams.asc,
          listFilter: transition.to.queryParams.username,
          query: params.filter,
          refreshing: false,
          bulkSelectedUsersMap: {},
          bulkSelectedUserIdsSet: new Set(),
          displayBulkActions: false,
        });

        controller.resetFilters();
      }
    }
  }
}
