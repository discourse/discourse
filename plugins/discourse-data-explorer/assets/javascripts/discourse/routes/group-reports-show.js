import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class GroupReportsShowRoute extends DiscourseRoute {
  @service router;

  model(params) {
    const group = this.modelFor("group");
    return ajax(`/g/${group.name}/reports/${params.query_id}`)
      .then((response) => {
        const query = response.query;
        const queryGroup = response.query_group;

        const queryParamInfo = query.param_info;
        const queryParams = queryParamInfo.reduce((acc, param) => {
          acc[param.identifier] = param.default;
          return acc;
        }, {});

        return {
          model: Object.assign({ params: queryParams }, query),
          group,
          queryGroup,
          results: null,
          showResults: false,
        };
      })
      .catch(() => {
        this.router.transitionTo("group.members", group);
      });
  }

  setupController(controller, model) {
    controller.setProperties(model);
  }
}
