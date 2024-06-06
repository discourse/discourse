import { service } from "@ember/service";
import Topic, { ID_CONSTRAINT } from "discourse/models/topic";
import DiscourseRoute from "discourse/routes/discourse";

export default class TopicBySlugOrId extends DiscourseRoute {
  @service router;

  model(params) {
    if (params.slug_or_id.match(ID_CONSTRAINT)) {
      return { url: `/t/topic/${params.slug_or_id}` };
    } else {
      return Topic.idForSlug(params.slug_or_id).then((data) => {
        return { url: `/t/${data.slug}/${data.topic_id}` };
      });
    }
  }

  afterModel(result) {
    this.router.transitionTo(result.url);
  }
}
