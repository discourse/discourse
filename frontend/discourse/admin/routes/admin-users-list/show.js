import DiscourseRoute from "discourse/routes/discourse";

export default class AdminUsersListShowRoute extends DiscourseRoute {
  queryParams = {
    username: { refreshModel: true },
  };

  setupController(controller, model, transition) {
    super.setupController(...arguments);

    const query = transition.to.params.filter;
    const { queryParams } = transition.to;
    const filter = queryParams.filter ?? queryParams.username;

    controller.setProperties({
      order: queryParams.order,
      asc: queryParams.asc,
      listFilter: filter,
      initialFilter: filter,
      query,
      activation: query === "new" ? queryParams.activation : null,
      bulkSelectedUsersMap: {},
      displayBulkActions: false,
    });

    controller.resetFilters();
  }
}
