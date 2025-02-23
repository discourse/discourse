import { action } from "@ember/object";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { queryParams, resetParams } from "discourse/controllers/discovery/list";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import { deepEqual } from "discourse/lib/object";
import { setTopicList } from "discourse/lib/topic-list-tracker";
import { defaultHomepage } from "discourse/lib/utilities";
import Session from "discourse/models/session";
import Site from "discourse/models/site";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

// A helper to build a topic route for a filter
export function filterQueryParams(params, defaultParams) {
  const findOpts = { ...(defaultParams || {}) };

  if (params) {
    Object.keys(queryParams).forEach(function (opt) {
      if (!isEmpty(params[opt])) {
        findOpts[opt] = params[opt];
      }
    });
  }
  return findOpts;
}

export async function findTopicList(
  store,
  tracking,
  filter,
  filterParams = {},
  extras = {}
) {
  let list;
  const session = Session.current();

  if (extras.cached) {
    const cachedList = session.get("topicList");

    // Try to use the cached version if it exists and is greater than the topics per page
    if (
      cachedList &&
      cachedList.get("filter") === filter &&
      (cachedList.get("topics.length") || 0) > cachedList.get("per_page") &&
      deepEqual(cachedList.get("listParams"), filterParams)
    ) {
      cachedList.set("loaded", true);

      tracking?.updateTopics(cachedList.get("topics"));
      list = cachedList;
    }

    session.set("topicList", null);
  } else {
    // Clear the cache
    session.setProperties({ topicList: null });
  }

  list ||= await store.findFiltered("topicList", {
    filter,
    params: filterParams,
  });

  list.set("listParams", filterParams);

  if (tracking) {
    tracking.sync(list, list.filter, filterParams);
    tracking.trackIncoming(list.filter);
  }

  Session.currentProp("topicList", list);

  if (list.topic_list?.top_tags) {
    if (list.filter.startsWith("c/") || list.filter.startsWith("tags/c/")) {
      Site.currentProp("category_top_tags", list.topic_list.top_tags);
    } else {
      Site.currentProp("top_tags", list.topic_list.top_tags);
    }
  }

  return list;
}

@disableImplicitInjections
class AbstractTopicRoute extends DiscourseRoute {
  @service screenTrack;
  @service store;
  @service topicTrackingState;
  @service currentUser;
  @service historyStore;

  queryParams = queryParams;
  templateName = "discovery/list";
  controllerName = "discovery/list";

  async model(data) {
    // attempt to stop early cause we need this to be called before .sync
    this.screenTrack.stop();

    const findOpts = filterQueryParams(data),
      findExtras = { cached: this.historyStore.isPoppedState };

    const topicListPromise = findTopicList(
      this.store,
      this.topicTrackingState,
      this.routeConfig.filter,
      findOpts,
      findExtras
    );

    return {
      list: await topicListPromise,
      filterType: this.routeConfig.filter.split("/")[0],
    };
  }

  titleToken() {
    if (this.routeConfig.filter === defaultHomepage()) {
      return;
    }

    const filterText = i18n(
      "filters." + this.routeConfig.filter.replace("/", ".") + ".title"
    );
    return i18n("filters.with_topics", { filter: filterText });
  }

  setupController(controller, model) {
    super.setupController(...arguments);
    controller.bulkSelectHelper.clear();
    setTopicList(model.list);
  }

  @action
  resetParams(skipParams = []) {
    resetParams.call(this, skipParams);
  }

  @action
  willTransition() {
    if (this.routeConfig.filter === "top" && this.currentUser) {
      this.currentUser.set("user_option.should_be_redirected_to_top", false);
      if (this.currentUser.user_option?.redirected_to_top) {
        this.currentUser.set("user_option.redirected_to_top.reason", null);
      }
    }
    return super.willTransition(...arguments);
  }
}

export default function buildTopicRoute(filter) {
  return class extends AbstractTopicRoute {
    routeConfig = { filter };
  };
}
