import Topic, { ID_CONSTRAINT } from "discourse/models/topic";
import DiscourseRoute from "discourse/routes/discourse";
import { inject as service } from "@ember/service";

export default DiscourseRoute.extend({
  router: service(),

  model(params) {
    if (params.slugOrId.match(ID_CONSTRAINT)) {
      return { url: `/t/topic/${params.slugOrId}` };
    } else {
      return Topic.idForSlug(params.slugOrId).then((data) => {
        return { url: `/t/${data.slug}/${data.topic_id}` };
      });
    }
  },

  afterModel(result) {
    this.router.transitionTo(result.url);
  },
});
