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
      topicsTotal: detail.topics_total ?? detail.ai_concept?.topics_count ?? 0,
      children: detail.children || [],
      neighborConcepts: detail.neighbor_concepts || [],
      coOccurringConcepts: detail.co_occurring_concepts || [],
      isNew: false,
    };
  }
}
