import { isEmpty } from "@ember/utils";
import { findOrResetCachedTopicList } from "discourse/lib/cached-topic-list";
import DiscourseRoute from "discourse/routes/discourse";
import {
  assignedListQueryParams,
  assignedListRequestParams,
} from "../../../lib/assigned-list-query-params.js";

// the session cache is keyed by filter alone, so a narrowed list must not
// cross it: guard both the incoming request and cached lists that
// TopicList.loadMore stored while a registered param was active
function narrowedByListParams(listParams) {
  return Object.keys(assignedListQueryParams()).some(
    (name) => !isEmpty(listParams?.[name])
  );
}

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

    const cachedList = findOrResetCachedTopicList(this.session, filter);
    const cached =
      !narrowedByListParams(params) && !narrowedByListParams(cachedList?.params)
        ? cachedList
        : null;

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
