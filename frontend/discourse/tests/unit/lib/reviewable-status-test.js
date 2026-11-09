import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  reviewableOutcomeName,
  reviewableOutcomeTimelineKey,
  reviewableProblemConfirmed,
} from "discourse/helpers/reviewable-status";
import {
  APPROVED,
  IGNORED,
  PENDING,
  REJECTED,
} from "discourse/models/reviewable";

module("Unit | Helper | reviewable-status", function (hooks) {
  setupTest(hooks);

  test("reviewableProblemConfirmed reads the status against the approval style", function (assert) {
    assert.true(reviewableProblemConfirmed(APPROVED, false), "agreed flag");
    assert.false(reviewableProblemConfirmed(REJECTED, false), "disagreed flag");
    assert.false(reviewableProblemConfirmed(APPROVED, true), "approved post");
    assert.true(reviewableProblemConfirmed(REJECTED, true), "rejected post");
    assert.strictEqual(reviewableProblemConfirmed(PENDING, true), undefined);
    assert.strictEqual(reviewableProblemConfirmed(IGNORED, false), undefined);
  });

  test("reviewableOutcomeName names the outcome the same way for every type", function (assert) {
    assert.strictEqual(
      reviewableOutcomeName(APPROVED, "ReviewableFlaggedPost", false),
      "problem_confirmed"
    );
    assert.strictEqual(
      reviewableOutcomeName(REJECTED, "ReviewableUser", true),
      "problem_confirmed"
    );
    assert.strictEqual(
      reviewableOutcomeName(REJECTED, "ReviewableFlaggedPost", false),
      "no_problem_found"
    );
    assert.strictEqual(
      reviewableOutcomeName(APPROVED, "ReviewableQueuedPost", true),
      "no_problem_found"
    );
    assert.strictEqual(
      reviewableOutcomeName(IGNORED, "ReviewableFlaggedPost", false),
      undefined
    );
  });

  test("reviewableOutcomeTimelineKey matches the status label", function (assert) {
    assert.strictEqual(
      reviewableOutcomeTimelineKey(REJECTED, "ReviewablePost", true),
      "review.timeline.problem_confirmed_by"
    );
    assert.strictEqual(
      reviewableOutcomeTimelineKey(REJECTED, "ReviewableFlaggedPost", false),
      "review.timeline.no_problem_found_by"
    );
  });
});
