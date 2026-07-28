import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import ReviewableTimeline from "discourse/components/reviewable/timeline";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | Reviewable | Timeline", function (hooks) {
  setupRenderingTest(hooks);

  function reviewableWithReason(reason) {
    return {
      reviewable_scores: [
        {
          created_at: "2024-01-01T00:00:00.000Z",
          user: { id: 1, username: "system" },
          score_type: { type: "needs_approval", title: "Needs Approval" },
          reason,
        },
      ],
    };
  }

  test("sanitizes dangerous markup in a flag reason but preserves safe links", async function (assert) {
    const reviewable = reviewableWithReason(
      `Spam detected <img src=x onerror=alert(1)> <a href="javascript:alert(2)">phish</a> <a href="/admin">see settings</a>`
    );

    await render(
      <template><ReviewableTimeline @reviewable={{reviewable}} /></template>
    );

    assert
      .dom(".timeline-event__description")
      .hasHtml(
        '<p>Spam detected <img src=""> <a>phish</a> <a href="/admin">see settings</a></p>',
        "renders the sanitized flag reason"
      );
  });
});
