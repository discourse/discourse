import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import ReviewableItem from "discourse/components/reviewable/item";
import { APPROVED, PENDING } from "discourse/models/reviewable";
import { CLAIMED, UNCLAIMED } from "discourse/models/reviewable-history";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { publishToMessageBus } from "discourse/tests/helpers/qunit-helpers";

function claimableReviewable(context, attrs = {}) {
  return getOwner(context)
    .lookup("service:store")
    .createRecord("reviewable", {
      id: 789,
      type: "topic",
      status: PENDING,
      topic: { id: 123, fancyTitle: "Test Topic Title" },
      target_url: "/t/test-topic/123",
      reviewable_scores: [],
      reviewable_histories: [],
      claimed_by: null,
      ...attrs,
    });
}

function publishClaim({ topicId = 123, claimed, automatic = false }) {
  return publishToMessageBus("/reviewable_claimed", {
    topic_id: topicId,
    user: { id: 7, username: "admin" },
    claimed,
    automatic,
  });
}

function historyTypes(reviewable) {
  return reviewable.reviewable_histories.map(
    (history) => history.reviewable_history_type
  );
}

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

    await publishClaim({ claimed: true });

    assert
      .dom(".reviewable-user-info")
      .exists("the item still renders and the broadcast is ignored");
  });

  test("tracks claim and release broadcasts for its topic", async function (assert) {
    const claimable = claimableReviewable(this);

    await render(
      <template><ReviewableItem @reviewable={{claimable}} /></template>
    );

    await publishClaim({ claimed: true });

    assert.strictEqual(
      claimable.claimed_by?.user?.username,
      "admin",
      "the reviewable is marked as claimed"
    );
    assert.deepEqual(
      historyTypes(claimable),
      [CLAIMED],
      "the claim is recorded in the timeline"
    );

    await publishClaim({ claimed: false });

    assert.strictEqual(
      claimable.claimed_by,
      null,
      "the reviewable is released"
    );
    assert.deepEqual(
      historyTypes(claimable),
      [CLAIMED, UNCLAIMED],
      "the unclaim is recorded in the timeline"
    );

    await publishClaim({ topicId: 999, claimed: true });

    assert.strictEqual(
      claimable.claimed_by,
      null,
      "a claim for a different topic is ignored"
    );
  });

  test("keeps automatic claims out of the timeline history", async function (assert) {
    const claimable = claimableReviewable(this);

    await render(
      <template><ReviewableItem @reviewable={{claimable}} /></template>
    );

    await publishClaim({ claimed: true, automatic: true });

    assert.true(
      claimable.claimed_by?.automatic,
      "the transient lock still applies"
    );

    await publishClaim({ claimed: false, automatic: true });

    assert.deepEqual(
      historyTypes(claimable),
      [],
      "an automatic claim is a transient lock, not a moderation event"
    );
  });

  test("keeps claims out of the timeline history of a resolved reviewable", async function (assert) {
    const resolved = claimableReviewable(this, { status: APPROVED });

    await render(
      <template><ReviewableItem @reviewable={{resolved}} /></template>
    );

    await publishClaim({ claimed: true });

    assert.strictEqual(
      resolved.claimed_by?.user?.username,
      "admin",
      "the claim is still reflected on a resolved reviewable"
    );

    await publishClaim({ claimed: false });

    assert.deepEqual(
      historyTypes(resolved),
      [],
      "the server only logs claims on pending reviewables"
    );
  });
});
