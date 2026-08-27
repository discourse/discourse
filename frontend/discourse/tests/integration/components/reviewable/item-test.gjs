import { tracked } from "@glimmer/tracking";
import { getOwner } from "@ember/owner";
import { click, fillIn, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import ReviewableItem from "discourse/components/reviewable/item";
import { withPluginApi } from "discourse/lib/plugin-api";
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

function plainReviewable(attrs = {}) {
  return { id: 456, topic: null, reviewable_scores: [], ...attrs };
}

function editableReviewable(id) {
  return plainReviewable({
    id,
    type: "ReviewableQueuedPost",
    can_edit: true,
    editable_fields: [{ id: "payload.title", type: "text" }],
    payload: { title: "Original title" },
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
    const topiclessReviewable = plainReviewable({ type: "ReviewableUser" });

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

  test("renders a component registered via the plugin API", async function (assert) {
    const CustomComponent = <template>
      <div class="custom-reviewable">{{@reviewable.type}}</div>
    </template>;

    withPluginApi((api) => {
      api.registerReviewableComponent(
        "ReviewableCustomThing",
        () => CustomComponent
      );
    });

    const customReviewable = {
      id: 987,
      type: "ReviewableCustomThing",
      topic: null,
      reviewable_scores: [],
    };

    await render(
      <template><ReviewableItem @reviewable={{customReviewable}} /></template>
    );

    assert.dom(".custom-reviewable").hasText("ReviewableCustomThing");
  });

  test("shows an error when no component exists for the reviewable type", async function (assert) {
    const unknownReviewable = {
      id: 988,
      type: "ReviewableMissingThing",
      topic: null,
      reviewable_scores: [],
    };

    await render(
      <template><ReviewableItem @reviewable={{unknownReviewable}} /></template>
    );

    assert
      .dom(".review-item__no-component")
      .hasText("No component found for ReviewableMissingThing");
  });

  test("renders a lazily loaded component registered via the plugin API", async function (assert) {
    const CustomComponent = <template>
      <div class="custom-reviewable">{{@reviewable.type}}</div>
    </template>;

    withPluginApi((api) => {
      api.registerReviewableComponent(
        "ReviewableCustomThing",
        async () => CustomComponent
      );
    });

    const customReviewable = {
      id: 987,
      type: "ReviewableCustomThing",
      topic: null,
      reviewable_scores: [],
    };

    await render(
      <template><ReviewableItem @reviewable={{customReviewable}} /></template>
    );

    assert.dom(".custom-reviewable").hasText("ReviewableCustomThing");
  });

  test("leaves edit mode when a different reviewable is passed in", async function (assert) {
    const state = new (class {
      @tracked reviewable = editableReviewable(1);
    })();

    await render(
      <template><ReviewableItem @reviewable={{state.reviewable}} /></template>
    );

    await click(".reviewable-action.edit");

    state.reviewable = editableReviewable(2);
    await settled();

    assert
      .dom(".editable-fields")
      .doesNotExist(
        "does not carry the pending edit over to the new reviewable"
      );
  });

  test("keeps a pending edit when the reviewable it belongs to is refreshed", async function (assert) {
    const queuedPost = getOwner(this)
      .lookup("service:store")
      .createRecord("reviewable", editableReviewable(1));

    await render(
      <template><ReviewableItem @reviewable={{queuedPost}} /></template>
    );

    await click(".reviewable-action.edit");
    await fillIn(".editable-field.payload-title input", "Edited first title");

    queuedPost.setProperties({ version: 2 });
    await settled();

    assert
      .dom(".editable-field.payload-title input")
      .hasValue(
        "Edited first title",
        "an in-place refresh of the same reviewable keeps the pending edit"
      );
  });

  test("goes back to the timeline tab when a different reviewable is passed in", async function (assert) {
    const state = new (class {
      @tracked reviewable = plainReviewable({ id: 1, type: "ReviewableUser" });
    })();

    await render(
      <template><ReviewableItem @reviewable={{state.reviewable}} /></template>
    );

    await click(".d-nav-submenu__tabs .insights a");

    assert
      .dom(".d-nav-submenu__tabs .insights a")
      .hasClass("active", "the insights tab is selected");
    assert.dom(".review-insight").exists("the insights tab is mounted");

    state.reviewable = plainReviewable({ id: 2, type: "ReviewableUser" });
    await settled();

    assert
      .dom(".d-nav-submenu__tabs .timeline a")
      .hasClass("active", "the new reviewable opens on its own timeline");
    assert
      .dom(".review-insight")
      .doesNotExist("the previous reviewable's insights are torn down");
  });
});
