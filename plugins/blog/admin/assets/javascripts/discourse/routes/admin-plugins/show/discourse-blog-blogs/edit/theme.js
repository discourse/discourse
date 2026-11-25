import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class BlogBlogsEditThemeRoute extends DiscourseRoute {
  async model() {
    const { blog } = this.modelFor(
      "adminPlugins.show.discourse-blog-blogs.edit"
    );
    // Previews open on this blog rather than the main one.
    const { themes, blogs } = await ajax("/admin/plugins/blog/themes.json", {
      data: { blog_id: blog.id },
    });
    return {
      blog,
      themes,
      activeOn: blogs.find((entry) => entry.id === blog.id),
    };
  }
}
