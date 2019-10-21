import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";

export default DiscourseRoute.extend({
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
