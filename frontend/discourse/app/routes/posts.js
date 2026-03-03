import { TrackedArray } from "@ember-compat/tracked-built-ins";
import Posts from "discourse/models/posts";
import DiscourseRoute from "discourse/routes/discourse";

export default class PostsRoute extends DiscourseRoute {
  async model() {
    const posts = await Posts.find();
    return new TrackedArray(posts);
  }
}
