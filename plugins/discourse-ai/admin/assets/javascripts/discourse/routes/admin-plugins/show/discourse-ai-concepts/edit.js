import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsShowDiscourseAiConceptsEditRoute extends DiscourseRoute {
  async model(params) {
    const [detail, list] = await Promise.all([
      ajax(`/admin/plugins/discourse-ai/ai-concepts/${params.id}.json`),
      ajax("/admin/plugins/discourse-ai/ai-concepts.json", {
        data: { status: "non_retired", order: "name", per_page: 200 },
      }),
    ]);

    return {
      concept: detail.ai_concept,
      topics: detail.topics || [],
      children: detail.children || [],
      availableConcepts: list.ai_concepts || [],
      isNew: false,
    };
  }
}
