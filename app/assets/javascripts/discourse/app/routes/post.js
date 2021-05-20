import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";

export default DiscourseRoute.extend({
  beforeModel({ params, _discourse_anchor }) {
    return ajax(`/p/${params.post.id}`).then((t) => {
      const transition = this.transitionTo(
        "topic.fromParamsNear",
        t.slug,
        t.id,
        t.current_post_number
      );

      transition._discourse_anchor = _discourse_anchor;
    });
  },
});
