import { service } from "@ember/service";
import Posts from "discourse/models/posts";
import DiscourseRoute from "discourse/routes/discourse";

export default class PostsRoute extends DiscourseRoute {
  @service router;

  async model() {
    return Posts.find();
  }
}
