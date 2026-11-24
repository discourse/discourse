import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsShowDiscourseAiConceptsNewRoute extends DiscourseRoute {
  async model() {
    const response = await ajax(
      "/admin/plugins/discourse-ai/ai-concepts.json",
      {
        data: { status: "non_retired", order: "name", per_page: 200 },
      }
    );

    return {
      concept: {
        name: "",
        description: "",
        aliases: [],
        status: "active",
        parent_id: null,
      },
      topics: [],
      children: [],
      availableConcepts: response.ai_concepts || [],
      isNew: true,
    };
  }
}
