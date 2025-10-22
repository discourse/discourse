import Controller, { inject as controller } from "@ember/controller";
import { action } from "@ember/object";

export default class GroupActivityPostsController extends Controller {
  @controller group;
  @controller("group.activity") groupActivity;
  @controller application;

  @action
  async fetchMorePosts() {
    const posts = this.model;
    const before =
      posts.length > 0 ? posts[posts.length - 1]?.created_at : undefined;
    const group = this.group.model;
    const categoryId = this.groupActivity.category_id;
    const opts = { before, type: this.type, categoryId };

    return await group.findPosts(opts);
  }
}
