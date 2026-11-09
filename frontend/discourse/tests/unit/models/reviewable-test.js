import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { PENDING, REJECTED } from "discourse/models/reviewable";

module("Unit | Model | reviewable", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    // The store reuses a record for a repeated id, so each build needs its own.
    let nextId = 1;
    this.build = (attrs) =>
      getOwner(this)
        .lookup("service:store")
        .createRecord("reviewable", {
          id: nextId++,
          status: PENDING,
          type_source: "core",
          approval_style: true,
          ...attrs,
        });
  });

  test("userReviewableContextQuestion asks whether approval-style items have a problem", function (assert) {
    assert.strictEqual(
      this.build({ type: "ReviewableQueuedPost", topic: { id: 1 } })
        .userReviewableContextQuestion,
      "Is there something wrong with this post?"
    );
    assert.strictEqual(
      this.build({ type: "ReviewableQueuedPost" })
        .userReviewableContextQuestion,
      "Is there something wrong with this topic?"
    );
    assert.strictEqual(
      this.build({ type: "ReviewablePost" }).userReviewableContextQuestion,
      "Is there something wrong with this post?"
    );
    assert.strictEqual(
      this.build({ type: "ReviewableUser" }).userReviewableContextQuestion,
      "Is there something wrong with this account?"
    );
  });

  test("userReviewableContextQuestion keeps the spam question for suspect users", function (assert) {
    const reviewable = this.build({
      type: "ReviewableUser",
      reviewable_scores: [{ reason_type: "suspect_user" }],
    });

    assert.strictEqual(
      reviewable.userReviewableContextQuestion,
      "Is this user spam?"
    );
  });

  test("userReviewableContextQuestion is absent for resolved items, flags and plugin approval types", function (assert) {
    assert.strictEqual(
      this.build({ type: "ReviewableUser", status: REJECTED })
        .userReviewableContextQuestion,
      null
    );
    assert.strictEqual(
      this.build({ type: "ReviewableQueuedPost", status: REJECTED })
        .userReviewableContextQuestion,
      null
    );
    assert.strictEqual(
      this.build({ type: "ReviewableFlaggedPost", approval_style: false })
        .userReviewableContextQuestion,
      null
    );
    assert.strictEqual(
      this.build({
        type: "ReviewableAiToolAction",
        type_source: "discourse-ai",
      }).userReviewableContextQuestion,
      null
    );
  });
});
