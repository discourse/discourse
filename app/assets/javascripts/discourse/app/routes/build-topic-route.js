import {
  changeSort,
  queryParams,
  resetParams,
} from "discourse/controllers/discovery-sortable";
import DiscourseRoute from "discourse/routes/discourse";
import I18n from "I18n";
import { Promise } from "rsvp";
import Session from "discourse/models/session";
import Site from "discourse/models/site";
import { deepEqual } from "discourse-common/lib/object";
import { defaultHomepage } from "discourse/lib/utilities";
import { isEmpty } from "@ember/utils";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";

// A helper to build a topic route for a filter
function filterQueryParams(params, defaultParams) {
  const findOpts = Object.assign({}, defaultParams || {});

  if (params) {
    Object.keys(queryParams).forEach(function (opt) {
      if (!isEmpty(params[opt])) {
        findOpts[opt] = params[opt];
      }
    });
  }
  return findOpts;
}

function findTopicList(store, tracking, filter, filterParams, extras) {
  extras = extras || {};
  return new Promise(function (resolve) {
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

        if (tracking) {
          tracking.updateTopics(cachedList.get("topics"));
        }
        return resolve(cachedList);
      }
      session.set("topicList", null);
    } else {
      // Clear the cache
      session.setProperties({ topicList: null, topicListScrollPosition: null });
    }

    // Clean up any string parameters that might slip through
    filterParams = filterParams || {};
    Object.keys(filterParams).forEach((k) => {
      const val = filterParams[k];
      if (val === "undefined" || val === "null") {
        filterParams[k] = null;
      }
    });

    return resolve(
      store.findFiltered("topicList", { filter, params: filterParams || {} })
    );
  }).then(function (list) {
    list.set("listParams", filterParams);
    if (tracking) {
      tracking.sync(list, list.filter, filterParams);
      tracking.trackIncoming(list.filter);
    }
    Session.currentProp("topicList", list);
    if (list.topic_list && list.topic_list.top_tags) {
      if (list.filter.startsWith("c/") || list.filter.startsWith("tags/c/")) {
        Site.currentProp("category_top_tags", list.topic_list.top_tags);
      } else {
        Site.currentProp("top_tags", list.topic_list.top_tags);
      }
    }
    return list;
  });
}

export default function (filter, extras) {
  extras = extras || {};
  return DiscourseRoute.extend(
    {
      screenTrack: service(),
      queryParams,

      beforeModel() {
        this.controllerFor("navigation/default").set(
          "filterType",
          filter.split("/")[0]
        );
      },

      model(data, transition) {
        // attempt to stop early cause we need this to be called before .sync
        this.screenTrack.stop();

        const findOpts = filterQueryParams(data),
          findExtras = { cached: this.isPoppedState(transition) };

        return findTopicList(
          this.store,
          this.topicTrackingState,
          filter,
          findOpts,
          findExtras
        );
      },

      titleToken() {
        if (filter === defaultHomepage()) {
          return;
        }

        const filterText = I18n.t(
          "filters." + filter.replace("/", ".") + ".title"
        );
        return I18n.t("filters.with_topics", { filter: filterText });
      },

      setupController(controller, model) {
        const topicOpts = {
          model,
          category: null,
          period: model.get("for_period") || model.get("params.period"),
          selected: [],
          expandAllPinned: false,
          expandGloballyPinned: true,
        };

        this.controllerFor("discovery/topics").setProperties(topicOpts);
        this.controllerFor("navigation/default").set(
          "canCreateTopic",
          model.get("can_create_topic")
        );
      },

      renderTemplate() {
        this.render("navigation/default", { outlet: "navigation-bar" });
        this.render("discovery/topics", {
          controller: "discovery/topics",
          outlet: "list-container",
        });
      },

      @action
      changeSort(sortBy) {
        changeSort.call(this, sortBy);
      },

      @action
      resetParams(skipParams = []) {
        resetParams.call(this, skipParams);
      },
    },
    extras
  );
}

export { filterQueryParams, findTopicList };
