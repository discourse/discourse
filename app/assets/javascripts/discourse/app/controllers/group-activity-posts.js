import Controller, { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
export default class GroupActivityPostsController extends Controller {
  @controller group;
  @controller groupActivity;
  @controller application;

  @action
  async fetchMorePosts() {
    const posts = this.model;
    const before = posts[posts.length - 1].created_at;
    const group = this.group.model;
    const categoryId = this.groupActivity.category_id;
    const opts = { before, type: this.type, categoryId };

    return await group.findPosts(opts);
  }
}
