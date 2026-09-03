import { service } from "@ember/service";
import resolvePermalink from "discourse/lib/permalink-check";
import Topic, { ID_CONSTRAINT } from "discourse/models/topic";
import DiscourseRoute from "discourse/routes/discourse";

export default class TopicBySlugOrId extends DiscourseRoute {
  @service router;

  afterModel(result) {
    if (result?.url) {
      this.router.transitionTo(result.url);
    }
  }

  model(params, transition) {
    if (params.slug_or_id.match(ID_CONSTRAINT)) {
      return { url: `/t/topic/${params.slug_or_id}` };
    }

    return Topic.idForSlug(params.slug_or_id)
      .then((data) => ({ url: `/t/${data.slug}/${data.topic_id}` }))
      .catch((error) =>
        resolvePermalink(`/t/${params.slug_or_id}`, transition).then(
          (result) => {
            if (result.type === "redirect") {
              // The permalink redirect already navigated away
              return {};
            }
            // Rethrow so the app-level 404 handling applies
            throw error;
          }
        )
      );
  }
}
