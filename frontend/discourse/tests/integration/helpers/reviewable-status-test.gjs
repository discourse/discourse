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
