import DiscourseRoute from "discourse/routes/discourse";

export default class UserDeletedPosts extends DiscourseRoute {
  templateName = "user/posts";
  controllerName = "user-posts";

  model() {
    return this.modelFor("user").postsStream;
  }

  afterModel(model) {
    return model.filterBy({ filter: "deleted" });
  }

  setupController(controller, model) {
    super.setupController(...arguments);

    model.set("canLoadMore", model.itemsLoaded === 60);
  }
}
