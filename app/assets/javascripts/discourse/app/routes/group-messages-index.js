import Route from "@ember/routing/route";
import { service } from "@ember/service";

export default Route.extend({
  router: service(),

  beforeModel() {
    this.router.transitionTo("group.messages.inbox");
  },
});
