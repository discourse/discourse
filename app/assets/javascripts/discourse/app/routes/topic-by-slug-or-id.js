import Topic, { ID_CONSTRAINT } from "discourse/models/topic";
import DiscourseRoute from "discourse/routes/discourse";
import { inject as service } from "@ember/service";

export default DiscourseRoute.extend({
  router: service(),

  model(params) {
    if (params.slugOrId.match(ID_CONSTRAINT)) {
      return { url: `/t/topic/${params.slugOrId}` };
    } else {
      return Topic.idForSlug(params.slugOrId);
    }
  },

  afterModel(result) {
    this.router.transitionTo(result.url);
  },
});
