import { service } from "@ember/service";
import UserTopicListRoute, {
  QUERY_PARAMS,
} from "discourse/routes/user-topic-list";
import { i18n } from "discourse-i18n";
import {
  assignedListQueryParams,
  assignedListRequestParams,
} from "../../lib/assigned-list-query-params.js";

export default class UserActivityAssigned extends UserTopicListRoute {
  @service currentUser;
  @service store;

  templateName = "user-activity.assigned";
  controllerName = "user-activity.assigned";

  userActionType = 16;
  noContentHelpKey = "discourse_assigns.no_assigns";

  // evaluated at route construction, after plugins have registered transformers
  queryParams = { ...QUERY_PARAMS, ...assignedListQueryParams() };

  beforeModel() {
    if (!this.currentUser) {
      this.send("showLogin");
    }
  }

  model(params) {
    return this.store.findFiltered("topicList", {
      filter: `topics/messages-assigned/${
        this.modelFor("user").username_lower
      }`,
      params: assignedListRequestParams(params, {
        exclude_category_ids: [-1],
        order: params.order,
        ascending: params.ascending,
        search: params.search,
      }),
    });
  }

  titleToken() {
    return i18n("discourse_assign.assigned");
  }
}
