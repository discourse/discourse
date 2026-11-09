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
      expectedClass: "no-problem-found",
    },
    {
      status: APPROVED,
      type: "ReviewableUser",
      expectedClass: "no-problem-found",
    },
    {
      status: APPROVED,
      type: "ReviewableFlaggedPost",
      expectedClass: "problem-confirmed",
    },
    {
      status: REJECTED,
      type: "ReviewableQueuedPost",
      expectedClass: "problem-confirmed",
    },
    {
      status: REJECTED,
      type: "ReviewableUser",
      expectedClass: "problem-confirmed",
    },
    {
      status: REJECTED,
      type: "ReviewableFlaggedPost",
      expectedClass: "no-problem-found",
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
    { status: APPROVED, type: undefined, expectedClass: "problem-confirmed" },
    { status: PENDING, type: undefined, expectedClass: "pending" },
    { status: REJECTED, type: undefined, expectedClass: "no-problem-found" },
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

  test("infers approval style from the type when it isn't passed", async function (assert) {
    await render(
      <template>
        <div class="legacy">{{newReviewableStatus
            APPROVED
            "ReviewableQueuedPost"
          }}</div>
        <div class="explicit">{{newReviewableStatus
            APPROVED
            "ReviewablePost"
            true
          }}</div>
        <div class="flag">{{newReviewableStatus
            APPROVED
            "ReviewableFlaggedPost"
            false
          }}</div>
      </template>
    );

    assert.dom(".legacy .review-item__status").hasText("No problem found");
    assert.dom(".explicit .review-item__status").hasText("No problem found");
    assert.dom(".flag .review-item__status").hasText("Problem confirmed");
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
