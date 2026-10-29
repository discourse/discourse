import { trustHTML } from "@ember/template";
import { ajax } from "discourse/lib/ajax";
import Category from "discourse/models/category";
import Post from "discourse/models/post";
import RestModel, { type RestModelAttrs } from "discourse/models/rest";

export default class Posts extends RestModel {
  static async find(
    opts: { before?: number; id?: number | string } = {}
  ): globalThis.Promise<Post[]> {
    const data: { before?: number; id?: number | string } = {};

    if (opts.before) {
      data.before = opts.before;
    }

    if (opts.id) {
      data.id = opts.id;
    }

    const { latest_posts }: { latest_posts: RestModelAttrs<Post>[] } =
      await ajax("/posts.json", { data });
    return latest_posts.map((post: RestModelAttrs<Post>) => {
      post.category = Category.findById(post.category_id);
      // Server titles are strings before this assignment wraps them as trusted HTML.
      post.topic_html_title = trustHTML(post.topic_html_title as string);
      return Post.create(post);
    });
  }
}
