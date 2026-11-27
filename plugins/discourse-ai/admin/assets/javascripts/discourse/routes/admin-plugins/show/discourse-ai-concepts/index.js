import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsShowDiscourseAiConceptsIndexRoute extends DiscourseRoute {
  async model(params, transition) {
    const query = transition?.to?.queryParams || params || {};
    const data = {};

    if (query.status && query.status !== "all") {
      data.status = query.status;
    }

    if (query.filter?.trim()) {
      data.filter = query.filter.trim();
    }

    if (query.order && query.order !== "usage") {
      data.order = query.order;
    }

    const response = await ajax(
      "/admin/plugins/discourse-ai/ai-concepts.json",
      { data }
    );

    return {
      ...response,
      queryParams: {
        status: query.status || "all",
        filter: query.filter || "",
        order: query.order || "usage",
      },
    };
  }
}
