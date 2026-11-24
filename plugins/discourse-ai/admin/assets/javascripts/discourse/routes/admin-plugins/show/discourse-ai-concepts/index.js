import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsShowDiscourseAiConceptsIndexRoute extends DiscourseRoute {
  queryParams = {
    status: { refreshModel: true },
    filter: { refreshModel: true },
    order: { refreshModel: true },
  };

  async model(params) {
    const data = {};

    if (params.status && params.status !== "all") {
      data.status = params.status;
    }

    if (params.filter?.trim()) {
      data.filter = params.filter.trim();
    }

    if (params.order && params.order !== "usage") {
      data.order = params.order;
    }

    return ajax("/admin/plugins/discourse-ai/ai-concepts.json", { data });
  }
}
