import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { isTesting } from "discourse/lib/environment";
import DiscourseURL from "discourse/lib/url";
import Draft from "discourse/models/draft";
import DiscourseRoute from "discourse/routes/discourse";

// This route is used for retrieving a topic based on params
export default class TopicFromParams extends DiscourseRoute {
  @service composer;
  @service header;
  @service router;

  // Avoid default model hook
  model(params) {
    params = params || {};
    params.track_visit = true;

    const topic = this.modelFor("topic");
    const postStream = topic.postStream;

    // I sincerely hope no topic gets this many posts
    if (params.nearPost === "last") {
      params.nearPost = 999999999;
    }
    params.forceLoad = true;

    return postStream
      .refresh(params)
      .then(() => params)
      .catch((e) => {
        if (!isTesting()) {
          // eslint-disable-next-line no-console
          console.log("Could not view topic", e);
        }
        params._loading_error = true;
        return params;
      });
  }

  afterModel(model) {
    const topic = this.modelFor("topic");

    if (topic.isPrivateMessage && topic.suggested_topics) {
      this.pmTopicTrackingState.startTracking();
    }

    const isLoadingFirstPost =
      topic.postStream.firstPostPresent &&
      !(model.nearPost && model.nearPost > 1);
    this.header.enterTopic(topic, isLoadingFirstPost);
  }

  deactivate() {
    super.deactivate(...arguments);
    this.controllerFor("topic").unsubscribe();
  }

  setupController(controller, params, { _discourse_anchor }) {
    // Don't do anything else if we couldn't load
    // TODO: Tests require this but it seems bad
    if (params._loading_error) {
      return;
    }

    const topicController = this.controllerFor("topic");
    const topic = this.modelFor("topic");
    const postStream = topic.postStream;

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
      enteredAt: Date.now().toString(),
      userLastReadPostNumber: topic.last_read_post_number,
      highestPostNumber: topic.highest_post_number,
    });

    this.appEvents.trigger("page:topic-loaded", topic);
    topicController.subscribe();

    // Highlight our post after the next render
    schedule("afterRender", () =>
      this.appEvents.trigger("post:highlight", closest)
    );

    const opts = {};
    if (document.location.hash) {
      opts.anchor = document.location.hash.slice(1);
    } else if (_discourse_anchor) {
      opts.anchor = _discourse_anchor;
    }
    DiscourseURL.jumpToPost(closest, opts);

    // completely clear out all the bookmark related attributes
    // because they are not in the response if bookmarked == false
    if (closestPost && !closestPost.bookmarked) {
      closestPost.clearBookmark();
    }

    if (!isEmpty(topic.draft)) {
      this.composer.open({
        draft: Draft.getLocal(topic.draft_key, topic.draft),
        draftKey: topic.draft_key,
        draftSequence: topic.draft_sequence,
        ignoreIfChanged: true,
        topic,
      });
    }
  }

  @action
  willTransition(transition) {
    this.controllerFor("topic").set("previousURL", document.location.pathname);

    transition.followRedirects().finally(() => {
      if (!this.router.currentRouteName.startsWith("topic.")) {
        this.header.clearTopic();
      }
    });

    // NOTE: omitting this return can break the back button when transitioning quickly between
    // topics and the latest page.
    return true;
  }
}
