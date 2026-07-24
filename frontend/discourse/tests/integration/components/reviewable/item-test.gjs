import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import ReviewableItem from "discourse/components/reviewable/item";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { publishToMessageBus } from "discourse/tests/helpers/qunit-helpers";

module("Integration | Component | Reviewable | Item", function (hooks) {
  setupRenderingTest(hooks);

  const reviewable = {
    topic: {
      fancyTitle: "Test Topic Title",
      id: 123,
    },
    target_url: "/t/test-topic/123",
    category: {
      id: 5,
      name: "General",
      color: "0088CC",
    },
    topic_tags: ["tag1", "tag2"],
    type: "topic",
    reviewable_scores: [],
    target_created_by: {
      id: 1,
      username: "testuser",
      name: "Test User",
      flags_agreed: 0,
    },
  };

  test("renders help resources ", async function (assert) {
    await render(
      <template>
        <ReviewableItem @reviewable={{reviewable}} @showHelp={{true}} />
      </template>
    );
    assert.dom(".review-item__resources").exists("renders the help content");
    assert
      .dom(
        `a.review-resources__link[href="https://meta.discourse.org/t/-/63116"]`
      )
      .exists();
    assert
      .dom(
        `a.review-resources__link[href="https://meta.discourse.org/t/-/123464"]`
      )
      .exists();
    assert
      .dom(
        `a.review-resources__link[href="https://meta.discourse.org/t/-/343541"]`
      )
      .exists();
  });

  test("does not render help resources when not required", async function (assert) {
    await render(
      <template><ReviewableItem @reviewable={{reviewable}} /></template>
    );
    assert
      .dom(".review-item__resources")
      .doesNotExist("does not render the help content");
  });

  test("does not error when a claim is broadcast for a reviewable without a topic", async function (assert) {
    // e.g. ReviewableUser / a queued new topic have no associated topic object
    const topiclessReviewable = {
      id: 456,
      type: "ReviewableUser",
      topic: null,
      reviewable_scores: [],
      payload: { username: "flagged-user" },
    };

    await render(
      <template>
        <ReviewableItem @reviewable={{topiclessReviewable}} />
      </template>
    );

    await publishToMessageBus("/reviewable_claimed", {
      topic_id: 123,
      user: { id: 7, username: "admin" },
      claimed: true,
    });

    assert
      .dom(".reviewable-user-info")
      .exists("the item still renders and the broadcast is ignored");
  });

  test("updates claimed_by when a claim is broadcast for its topic", async function (assert) {
    const claimable = getOwner(this)
      .lookup("service:store")
      .createRecord("reviewable", {
        id: 789,
        type: "topic",
        topic: { id: 123, fancyTitle: "Test Topic Title" },
        target_url: "/t/test-topic/123",
        reviewable_scores: [],
        reviewable_histories: [],
        claimed_by: null,
      });

    await render(
      <template><ReviewableItem @reviewable={{claimable}} /></template>
    );

    await publishToMessageBus("/reviewable_claimed", {
      topic_id: 123,
      user: { id: 7, username: "admin" },
      claimed: true,
    });

    assert.strictEqual(
      claimable.claimed_by?.user?.username,
      "admin",
      "the reviewable is marked as claimed"
    );

    await publishToMessageBus("/reviewable_claimed", {
      topic_id: 999,
      user: { id: 8, username: "other-admin" },
      claimed: true,
    });

    assert.strictEqual(
      claimable.claimed_by?.user?.username,
      "admin",
      "a claim for a different topic is ignored"
    );
  });
});
