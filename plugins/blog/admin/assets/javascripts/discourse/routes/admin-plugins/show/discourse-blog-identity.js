import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import { defaultBlog } from "discourse/plugins/blog/discourse/lib/site-blogs";

// Keeps links to the old identity page working.
export default class BlogIdentityRoute extends DiscourseRoute {
  @service router;
  @service site;

  redirect() {
    const blog = defaultBlog(this.site);
    if (!blog) {
      return this.router.replaceWith("adminPlugins.show.discourse-blog-blogs");
    }
    this.router.replaceWith(
      "adminPlugins.show.discourse-blog-blogs.edit.about",
      blog.id
    );
  }
}
