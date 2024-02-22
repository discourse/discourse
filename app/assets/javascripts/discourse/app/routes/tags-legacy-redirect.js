import Route from "@ember/routing/route";
import { inject as service } from "@ember/service";

export default Route.extend({
  router: service(),

  beforeModel() {
    this.router.transitionTo(
      "tag.show",
      this.paramsFor("tags.legacyRedirect").tag_id
    );
  },
});
