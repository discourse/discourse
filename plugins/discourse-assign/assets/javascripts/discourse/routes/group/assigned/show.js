import { findOrResetCachedTopicList } from "discourse/lib/cached-topic-list";
import DiscourseRoute from "discourse/routes/discourse";

export default class GroupAssignedShow extends DiscourseRoute {
  model(params) {
    let filter;
    if (["everyone", this.modelFor("group").name].includes(params.filter)) {
      filter = `topics/group-topics-assigned/${this.modelFor("group").name}`;
    } else {
      filter = `topics/messages-assigned/${params.filter}`;
    }

    return (
      findOrResetCachedTopicList(this.session, filter) ||
      this.store.findFiltered("topicList", {
        filter,
        params: {
          order: params.order,
          ascending: params.ascending,
          search: params.search,
          direct: params.filter !== "everyone",
        },
      })
    );
  }

  setupController(controller, model) {
    controller.setProperties({
      model,
      search: this.currentModel.params.search,
    });
  }
}
