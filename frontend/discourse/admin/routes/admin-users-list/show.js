import { USER_ACCOUNT_TYPES } from "discourse/admin/lib/user-account-types";
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
    const accountType = queryParams.account_type;

    controller.setProperties({
      order: queryParams.order,
      asc: queryParams.asc,
      listFilter: filter,
      initialFilter: filter,
      query,
      accountType:
        query === "staff" &&
        Object.values(USER_ACCOUNT_TYPES).includes(accountType)
          ? accountType
          : USER_ACCOUNT_TYPES.HUMAN,
      activation: query === "new" ? queryParams.activation : null,
      bulkSelectedUsersMap: {},
      displayBulkActions: false,
    });

    controller.resetFilters();
  }
}
