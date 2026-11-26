import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { APPROVED, PENDING } from "discourse/models/reviewable";

module("Unit | Model | reviewable-ai-tool-action", function (hooks) {
  setupTest(hooks);

  test("shows the AI action approval heading while a tool request is pending", function (assert) {
    const owner = getOwner(this);
    owner.lookup("service:site-settings").review_queue_consistent_answers =
      true;
    const reviewable = owner
      .lookup("service:store")
      .createRecord("reviewable", {
        id: 1,
        type: "ReviewableAiToolAction",
        type_source: "discourse-ai",
        approval_style: true,
        status: PENDING,
      });

    assert.strictEqual(
      reviewable.userReviewableContextQuestion,
      "AI action approval"
    );
    reviewable.status = APPROVED;
    assert.strictEqual(reviewable.userReviewableContextQuestion, null);
  });
});
