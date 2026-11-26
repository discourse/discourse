import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class BlogBlogsEditRoute extends DiscourseRoute {
  async model({ blog_id }) {
    return { blog: await ajax(`/admin/plugins/blog/blogs/${blog_id}.json`) };
  }
}
