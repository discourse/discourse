import Topic, { ID_CONSTRAINT } from "discourse/models/topic";
import DiscourseRoute from "discourse/routes/discourse";
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
    // Using { replaceURL: true } to replace the current incomplete URL with
    // the complete one is working incorrectly.
    //
    // Let's consider an example where the user is at /t/-/1. If they click on
    // a link to /t/2 the expected behavior is to take the user to /t/2 that
    // will redirect to /t/-/2 and generate a history with two entries: /t/-/1
    // followed by /t/-/2.
    //
    // When { replaceURL: true } is present, the history contains a single
    // entry /t/-/2. This suggests that `afterModel` is called in the context
    // of the referrer replacing its entry with the new one.
    DiscourseURL.routeTo(result.url);
  },
});
