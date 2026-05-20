import { module, test } from "qunit";
import PostVotingAnswerHeader from "discourse/plugins/discourse-post-voting/discourse/components/post-voting-answer-header";

module("Unit | Component | post-voting-answer-header", function () {
  test("shouldRender is false without flat topic page outlet args", function (assert) {
    const topic = { is_post_voting: true };
    const post = { topic };

    assert.false(
      PostVotingAnswerHeader.shouldRender({ post }),
      "does not render in nested post outlets"
    );
  });

  test("shouldRender is true above the first answer in flat topic view", function (assert) {
    const topic = {
      is_post_voting: true,
      posts_count: 2,
      postStream: { stream: [1, 2] },
    };
    const post = { id: 2, topic };

    assert.true(
      PostVotingAnswerHeader.shouldRender({
        post,
        actions: { updateTopicPageQueryParams() {} },
        topicPageQueryParams: {},
      })
    );
  });
});
