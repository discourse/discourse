import DiscourseRoute from "discourse/routes/discourse";
import { inject as service } from "@ember/service";

export default DiscourseRoute.extend({
  router: service(),

  model(params) {
    return this.store.find("post", params.id);
  },

  afterModel(post) {
    this.router.transitionTo(post.url);
  },
});
