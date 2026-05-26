import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsExplorerQueriesDetails extends DiscourseRoute {
  @service siteSettings;

  queryParams = {
    autoRun: {
      as: "run",
      refreshModel: false,
    },
  };

  model(params, transition) {
    if (!this.currentUser.admin) {
      // display "Only available to admins" message
      return { model: null, schema: null, disallow: true, groups: null };
    }

    const groupPromise = ajax(
      "/admin/plugins/discourse-data-explorer/groups.json"
    );
    const schemaPromise = ajax(
      "/admin/plugins/discourse-data-explorer/schema.json",
      {
        cache: true,
      }
    );

    const data = {};
    const urlParams = transition.to.queryParams.params;
    if (urlParams) {
      data.params = urlParams;
    }
    const queryPromise = ajax(
      `/admin/plugins/discourse-data-explorer/queries/${params.query_id}`,
      { data }
    );

    return groupPromise.then((groups) => {
      let groupNames = {};
      groups.forEach((g) => {
        groupNames[g.id] = g.name;
      });
      return schemaPromise.then((schema) => {
        return queryPromise.then((queryResponse) => {
          const model = this.store.createRecord("query", queryResponse.query);
          model.set(
            "group_names",
            (model.group_ids || []).map((id) => groupNames[id])
          );
          return { model, schema, groups };
        });
      });
    });
  }

  setupController(controller, model, transition) {
    controller._teardownAi();

    const cachedResult = model.model.cached_result;
    const shouldAutoRun = !!transition.to.queryParams.run;
    const showCachedResult = !!cachedResult && !shouldAutoRun;
    const defaultMode =
      this.siteSettings.data_explorer_ai_queries_enabled &&
      !model.model.is_default
        ? "ai"
        : "manual";

    controller.setProperties({
      ...model,
      results: showCachedResult ? cachedResult : null,
      showResults: showCachedResult,
      isCachedResult: showCachedResult,
      shouldAutoRun,
      mode: defaultMode,
      aiPrompt: "",
      lastGeneratedPrompt: null,
    });
    controller.snapshotPristine();
    controller.initView();
  }

  resetController(controller, isExiting) {
    if (isExiting) {
      controller._teardownAi();
    }
  }
}
