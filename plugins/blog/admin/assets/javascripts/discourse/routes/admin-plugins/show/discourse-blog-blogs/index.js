import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

// Loaded on each visit, so the list is current after a blog is added or deleted.
export default class BlogBlogsIndexRoute extends DiscourseRoute {
  model() {
    return ajax("/admin/plugins/blog/blogs.json");
  }
}
