import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  router: service(),

  model(params) {
    return this.store.find("post", params.id);
  },

  afterModel(post) {
    this.router.transitionTo(post.url);
  },
});
