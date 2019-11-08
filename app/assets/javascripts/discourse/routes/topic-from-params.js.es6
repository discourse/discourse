import { isEmpty } from "@ember/utils";
import { scheduleOnce } from "@ember/runloop";
import DiscourseRoute from "discourse/routes/discourse";
import DiscourseURL from "discourse/lib/url";
import Draft from "discourse/models/draft";
import ENV from "discourse-common/config/environment";

// This route is used for retrieving a topic based on params
export default DiscourseRoute.extend({
  // Avoid default model hook
  model(params) {
    return params;
  },

  deactivate() {
    this._super(...arguments);
    this.controllerFor("topic").unsubscribe();
  },

  setupController(controller, params) {
    params = params || {};
    params.track_visit = true;

    const topic = this.modelFor("topic"),
      postStream = topic.postStream,
      topicController = this.controllerFor("topic"),
      composerController = this.controllerFor("composer");

    // I sincerely hope no topic gets this many posts
    if (params.nearPost === "last") {
      params.nearPost = 999999999;
    }

    params.forceLoad = true;

    postStream
      .refresh(params)
      .then(() => {
        // TODO we are seeing errors where closest post is null and this is exploding
        // we need better handling and logging for this condition.

        // there are no closestPost for hidden topics
        if (topic.view_hidden) {
          return;
        }

        // The post we requested might not exist. Let's find the closest post
        const closestPost = postStream.closestPostForPostNumber(
          params.nearPost || 1
        );
        const closest = closestPost.post_number;

        topicController.setProperties({
          "model.currentPost": closest,
          enteredIndex: topic.postStream.progressIndexOfPost(closestPost),
          enteredAt: new Date().getTime().toString()
        });

        this.appEvents.trigger("page:topic-loaded", topic);
        topicController.subscribe();

        // Highlight our post after the next render
        scheduleOnce("afterRender", () =>
          this.appEvents.trigger("post:highlight", closest)
        );

        const opts = {};
        if (document.location.hash && document.location.hash.length) {
          opts.anchor = document.location.hash;
        }
        DiscourseURL.jumpToPost(closest, opts);

        if (!isEmpty(topic.draft)) {
          composerController.open({
            draft: Draft.getLocal(topic.draft_key, topic.draft),
            draftKey: topic.draft_key,
            draftSequence: topic.draft_sequence,
            ignoreIfChanged: true,
            topic
          });
        }
      })
      .catch(e => {
        if (ENV.environment !== "test") {
          // eslint-disable-next-line no-console
          console.log("Could not view topic", e);
        }
      });
  },

  actions: {
    willTransition() {
      this.controllerFor("topic").set(
        "previousURL",
        document.location.pathname
      );

      // NOTE: omitting this return can break the back button when transitioning quickly between
      // topics and the latest page.
      return true;
    }
  }
});
