import Posts from "discourse/models/posts";
import DiscourseRoute from "discourse/routes/discourse";

export default class PostsRoute extends DiscourseRoute {
  async model() {
    return Posts.find();
  }
}
