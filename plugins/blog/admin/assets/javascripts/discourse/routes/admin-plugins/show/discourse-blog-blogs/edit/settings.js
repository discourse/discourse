import DiscourseRoute from "discourse/routes/discourse";

export default class BlogBlogsEditSettingsRoute extends DiscourseRoute {
  model() {
    return this.modelFor("adminPlugins.show.discourse-blog-blogs.edit");
  }
}
