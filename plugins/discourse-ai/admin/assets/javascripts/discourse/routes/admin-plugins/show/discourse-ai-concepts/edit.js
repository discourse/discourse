import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsShowDiscourseAiConceptsEditRoute extends DiscourseRoute {
  async model(params) {
    const detail = await ajax(
      `/admin/plugins/discourse-ai/ai-concepts/${params.id}.json`
    );

    return {
      concept: detail.ai_concept,
      topics: detail.topics || [],
      children: detail.children || [],
      isNew: false,
    };
  }
}
