import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class BlogAppearanceRoute extends DiscourseRoute {
  @service router;

  redirect() {
    this.router.replaceWith("adminPlugins.show.discourse-blog-themes");
  }
}
