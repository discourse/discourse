import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  reviewableOutcome,
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

  hooks.beforeEach(function () {
    this.siteSettings = getOwner(this).lookup("service:site-settings");
  });

  test("reviewableProblemConfirmed reads the status against the approval style", function (assert) {
    assert.true(reviewableProblemConfirmed(APPROVED, false), "agreed flag");
    assert.false(reviewableProblemConfirmed(REJECTED, false), "disagreed flag");
    assert.false(reviewableProblemConfirmed(APPROVED, true), "approved post");
    assert.true(reviewableProblemConfirmed(REJECTED, true), "rejected post");
    assert.strictEqual(reviewableProblemConfirmed(PENDING, true), undefined);
    assert.strictEqual(reviewableProblemConfirmed(IGNORED, false), undefined);
  });

  test("reviewableOutcome names what was approved or rejected without consistent answers", function (assert) {
    this.siteSettings.review_queue_consistent_answers = false;

    assert.deepEqual(
      reviewableOutcome(APPROVED, "ReviewableFlaggedPost", false),
      {
        name: "approved_flag",
        icon: "check",
        cssClass: "approved",
        timelineKey: "review.timeline.approved_by",
      }
    );
    assert.strictEqual(
      reviewableOutcome(APPROVED, "ReviewablePost", true).name,
      "approved_post",
      "a post needing approval isn't labelled as a flag"
    );
    assert.strictEqual(
      reviewableOutcome(REJECTED, "ReviewableUser", true).name,
      "rejected_user"
    );
  });

  test("reviewableOutcome describes whether a problem was confirmed with consistent answers", function (assert) {
    this.siteSettings.review_queue_consistent_answers = true;

    assert.deepEqual(
      reviewableOutcome(APPROVED, "ReviewableFlaggedPost", false),
      {
        name: "problem_confirmed",
        icon: "xmark",
        cssClass: "problem-confirmed",
        timelineKey: "review.timeline.problem_confirmed_by",
      }
    );
    assert.deepEqual(
      reviewableOutcome(APPROVED, "ReviewableQueuedPost", true),
      {
        name: "no_problem_found",
        icon: "check",
        cssClass: "no-problem-found",
        timelineKey: "review.timeline.no_problem_found_by",
      }
    );
    assert.strictEqual(
      reviewableOutcome(IGNORED, "ReviewableFlaggedPost", false),
      undefined
    );
  });

  test("reviewableOutcome keeps approved/rejected wording for reviewables that don't answer whether there's a problem", function (assert) {
    this.siteSettings.review_queue_consistent_answers = true;

    assert.deepEqual(
      reviewableOutcome(APPROVED, "ReviewablePluginNomination", false, false),
      {
        name: "approved_flag",
        icon: "check",
        cssClass: "approved",
        timelineKey: "review.timeline.approved_by",
      }
    );
    assert.strictEqual(
      reviewableOutcome(REJECTED, "ReviewablePluginNomination", false, false)
        .cssClass,
      "rejected"
    );
  });
});
