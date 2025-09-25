import { service } from "@ember/service";
import UserTopicListRoute from "discourse/routes/user-topic-list";
import { i18n } from "discourse-i18n";

export default class UserActivityAssigned extends UserTopicListRoute {
  @service router;

  templateName = "user-activity.assigned";
  controllerName = "user-activity.assigned";

  userActionType = 16;
  noContentHelpKey = "discourse_assigns.no_assigns";

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
      params: {
        exclude_category_ids: [-1],
        order: params.order,
        ascending: params.ascending,
        search: params.search,
      },
    });
  }

  titleToken() {
    return i18n("discourse_assign.assigned");
  }
}
