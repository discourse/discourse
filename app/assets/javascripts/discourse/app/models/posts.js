import { ajax } from "discourse/lib/ajax";
import Category from "discourse/models/category";
import Post from "discourse/models/post";
import RestModel from "discourse/models/rest";

export default class Posts extends RestModel {
  static async find(opts = {}) {
    const data = {};

    if (opts.before) {
      data.before = opts.before;
    }

    if (opts.id) {
      data.id = opts.id;
    }

    const { latest_posts } = await ajax("/posts.json", { data });
    return latest_posts.map((post) => {
      post.category = Category.findById(post.category_id);
      return Post.create(post);
    });
  }
}
