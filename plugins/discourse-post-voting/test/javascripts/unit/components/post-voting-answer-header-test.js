import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import PostVotingAnswerHeader from "discourse/plugins/discourse-post-voting/discourse/components/post-voting-answer-header";

function createMegaTopic(context, postNumbers) {
  const store = getOwner(context).lookup("service:store");
  const topic = store.createRecord("topic", {
    id: 1,
    is_post_voting: true,
    posts_count: 10_000,
  });
  topic.postStream.isMegaTopic = true;

  return postNumbers.map((postNumber) =>
    topic.postStream.appendPost(
      store.createRecord("post", {
        id: 10 + postNumber,
        post_number: postNumber,
      })
    )
  );
}

module("Unit | Component | post-voting-answer-header", function (hooks) {
  setupTest(hooks);

  test("renders above the first answer on mega topics", function (assert) {
    const [, answer] = createMegaTopic(this, [1, 2]);

    assert.true(
      PostVotingAnswerHeader.shouldRender({
        post: answer,
        topicPageQueryParams: {},
      })
    );
  });

  test("does not render on mega topics loaded past the first post", function (assert) {
    const [, post] = createMegaTopic(this, [500, 501]);

    assert.false(
      PostVotingAnswerHeader.shouldRender({ post, topicPageQueryParams: {} })
    );
  });
});
