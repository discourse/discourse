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

  async model(params, transition) {
    if (params.slug_or_id.match(ID_CONSTRAINT)) {
      return { url: `/t/topic/${params.slug_or_id}` };
    }

    try {
      const { slug, topic_id } = await Topic.idForSlug(params.slug_or_id);
      return { url: `/t/${slug}/${topic_id}` };
    } catch (error) {
      if (error?.jqXHR?.status !== 404) {
        throw error;
      }
      const permalink = await resolvePermalink(
        `/t/${params.slug_or_id}`,
        transition,
        this.router
      ).catch(() => null);
      if (permalink?.type === "redirect") {
        return {};
      }
      throw error;
    }
  }
}
