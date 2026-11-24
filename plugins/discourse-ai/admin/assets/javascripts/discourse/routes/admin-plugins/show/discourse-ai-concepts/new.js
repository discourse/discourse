import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsShowDiscourseAiConceptsNewRoute extends DiscourseRoute {
  model() {
    return {
      concept: {
        name: "",
        description: "",
        aliases: [],
        status: "active",
        parent_id: null,
        parent_name: null,
      },
      topics: [],
      children: [],
      isNew: true,
    };
  }
}
