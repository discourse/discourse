import Route from "@ember/routing/route";
import { inject as service } from "@ember/service";

export default Route.extend({
  router: service(),

  beforeModel() {
    const group = this.modelFor("group");
    if (group.can_see_members) {
      this.router.transitionTo("group.activity.posts");
    } else {
      this.router.transitionTo("group.activity.mentions");
    }
  },
});
