import { ajax } from "discourse/lib/ajax";

export default Discourse.Route.extend({
  beforeModel({ params }) {
    return ajax(`/p/${params.post.id}`).then(t => {
      this.transitionTo(
        "topic.fromParamsNear",
        t.slug,
        t.id,
        t.current_post_number
      );
    });
  }
});
