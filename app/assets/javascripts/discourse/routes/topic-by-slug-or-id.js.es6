import DiscourseRoute from "discourse/routes/discourse";
import Topic, { ID_CONSTRAINT } from "discourse/models/topic";
import DiscourseURL from "discourse/lib/url";

export default DiscourseRoute.extend({
  model(params) {
    if (params.slugOrId.match(ID_CONSTRAINT)) {
      return { url: `/t/topic/${params.slugOrId}` };
    } else {
      return Topic.idForSlug(params.slugOrId);
    }
  },

  afterModel(result) {
    DiscourseURL.routeTo(result.url, { replaceURL: true });
  }
});
