import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class BlogEditorRoute extends DiscourseRoute {
  @service currentUser;
  @service router;

  beforeModel(transition) {
    if (!this.currentUser) {
      transition.send("showLogin");
      return;
    }
    if (!(this.currentUser.can_blog_edit ?? this.currentUser.staff)) {
      return this.router.transitionTo("discovery.latest");
    }
  }

  model() {
    if (this.currentUser?.can_blog_edit ?? this.currentUser?.staff) {
      return ajax("/blog/editor.json");
    }
  }
}
