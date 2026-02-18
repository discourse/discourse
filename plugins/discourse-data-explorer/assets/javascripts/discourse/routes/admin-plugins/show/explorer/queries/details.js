import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsExplorerQueriesDetails extends DiscourseRoute {
  queryParams = {
    autoRun: {
      as: "run",
      refreshModel: false,
    },
  };

  model(params) {
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
    const queryPromise = this.store.find("query", params.query_id);

    return groupPromise.then((groups) => {
      let groupNames = {};
      groups.forEach((g) => {
        groupNames[g.id] = g.name;
      });
      return schemaPromise.then((schema) => {
        return queryPromise.then((model) => {
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
    controller.setProperties({
      ...model,
      shouldAutoRun: !!transition.to.queryParams.run,
    });
  }
}
