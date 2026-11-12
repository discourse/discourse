import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { newReviewableStatus } from "discourse/helpers/reviewable-status";
import {
  APPROVED,
  DELETED,
  IGNORED,
  PENDING,
  REJECTED,
} from "discourse/models/reviewable";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Helper | reviewable-status", function (hooks) {
  setupRenderingTest(hooks);

  const statusTestCases = [
    {
      status: PENDING,
      type: "ReviewableQueuedPost",
      expectedClass: "pending",
    },
    {
      status: APPROVED,
      type: "ReviewableQueuedPost",
      expectedClass: "approved",
    },
    {
      status: APPROVED,
      type: "ReviewableUser",
      expectedClass: "approved",
    },
    {
      status: APPROVED,
      type: "ReviewableFlaggedPost",
      expectedClass: "approved",
    },
    {
      status: REJECTED,
      type: "ReviewableQueuedPost",
      expectedClass: "rejected",
    },
    {
      status: REJECTED,
      type: "ReviewableUser",
      expectedClass: "rejected",
    },
    {
      status: REJECTED,
      type: "ReviewableFlaggedPost",
      expectedClass: "rejected",
    },
    {
      status: IGNORED,
      type: "ReviewableFlaggedPost",
      expectedClass: "ignored",
    },
    {
      status: DELETED,
      type: "ReviewableQueuedPost",
      expectedClass: "deleted",
    },
    { status: APPROVED, type: undefined, expectedClass: "approved" },
    { status: PENDING, type: undefined, expectedClass: "pending" },
    { status: REJECTED, type: undefined, expectedClass: "rejected" },
    { status: IGNORED, type: undefined, expectedClass: "ignored" },
    { status: DELETED, type: undefined, expectedClass: "deleted" },
  ];

  test.each(
    "status rendering",
    statusTestCases,
    async function (assert, testCase) {
      await render(
        <template>
          <div class="test">{{newReviewableStatus
              testCase.status
              testCase.type
            }}</div>
        </template>
      );

      assert
        .dom(`.review-item__status.--${testCase.expectedClass}`)
        .exists(`has ${testCase.expectedClass} CSS class`);
    }
  );

  test("labels a post needing approval as a post rather than a flag", async function (assert) {
    await render(
      <template>
        <div class="legacy">{{newReviewableStatus
            APPROVED
            "ReviewablePost"
          }}</div>
        <div class="explicit">{{newReviewableStatus
            APPROVED
            "ReviewablePost"
            true
          }}</div>
      </template>
    );

    assert.dom(".legacy .review-item__status").hasText("Post approved");
    assert.dom(".explicit .review-item__status").hasText("Post approved");
  });

  test("labels outcomes by problem with consistent answers", async function (assert) {
    this.siteSettings.review_queue_consistent_answers = true;

    await render(
      <template>
        <div class="agreed-flag">{{newReviewableStatus
            APPROVED
            "ReviewableFlaggedPost"
            false
          }}</div>
        <div class="rejected-post">{{newReviewableStatus
            REJECTED
            "ReviewableQueuedPost"
            true
          }}</div>
        <div class="approved-user">{{newReviewableStatus
            APPROVED
            "ReviewableUser"
          }}</div>
      </template>
    );

    assert
      .dom(".agreed-flag .review-item__status.--problem-confirmed")
      .hasText("Problem confirmed");
    assert
      .dom(".rejected-post .review-item__status.--problem-confirmed")
      .hasText("Problem confirmed");
    assert
      .dom(".approved-user .review-item__status.--no-problem-found")
      .hasText("No problem found", "infers approval style from the type");
  });

  const edgeCaseTestCases = [
    {
      status: 999,
      type: "ReviewableQueuedPost",
    },
    {
      status: undefined,
      type: "ReviewableQueuedPost",
    },
  ];

  test.each("edge cases", edgeCaseTestCases, async function (assert, testCase) {
    await render(
      <template>
        <div class="test">{{newReviewableStatus
            testCase.status
            testCase.type
          }}</div>
      </template>
    );

    assert
      .dom(".review-item__status")
      .doesNotExist("no element rendered for invalid/undefined status");
  });
});
