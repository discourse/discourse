import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class DiscourseAiUsageRoute extends DiscourseRoute {
  queryParams = {
    period: { replace: true },
    start_date: { replace: true },
    end_date: { replace: true },
    feature: { replace: true },
    selectedModel: { replace: true },
  };

  async model(params) {
    const data = await ajax("/admin/plugins/discourse-ai/ai-usage.json");
    const queryParams = {
      ...params,
      model: params.selectedModel || params.model,
    };
    delete queryParams.selectedModel;

    return {
      data,
      queryParams,
    };
  }
}
