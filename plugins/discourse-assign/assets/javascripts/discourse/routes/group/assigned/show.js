import { isEmpty } from "@ember/utils";
import { findOrResetCachedTopicList } from "discourse/lib/cached-topic-list";
import DiscourseRoute from "discourse/routes/discourse";
import {
  assignedListQueryParams,
  assignedListRequestParams,
} from "../../../lib/assigned-list-query-params.js";

export default class GroupAssignedShow extends DiscourseRoute {
  // evaluated at route construction, after plugins have registered transformers
  queryParams = { ...assignedListQueryParams() };

  model(params) {
    let filter;
    if (["everyone", this.modelFor("group").name].includes(params.filter)) {
      filter = `topics/group-topics-assigned/${this.modelFor("group").name}`;
    } else {
      filter = `topics/messages-assigned/${params.filter}`;
    }

    // the session cache is keyed by filter alone and cannot represent a
    // registered param narrowing the list, so fetch fresh when one is set
    const narrowed = Object.keys(assignedListQueryParams()).some(
      (name) => !isEmpty(params[name])
    );
    const cached = narrowed
      ? null
      : findOrResetCachedTopicList(this.session, filter);

    return (
      cached ||
      this.store.findFiltered("topicList", {
        filter,
        params: assignedListRequestParams(params, {
          order: params.order,
          ascending: params.ascending,
          search: params.search,
          direct: params.filter !== "everyone",
        }),
      })
    );
  }

  setupController(controller, model) {
    controller.setProperties({
      model,
      search: this.currentModel.params.search,
    });
  }
}
