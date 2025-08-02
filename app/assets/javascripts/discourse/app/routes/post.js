import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class Post extends DiscourseRoute {
  @service router;

  model(params) {
    return this.store.find("post", params.id);
  }

  afterModel(post) {
    this.router.transitionTo(post.url);
  }
}
