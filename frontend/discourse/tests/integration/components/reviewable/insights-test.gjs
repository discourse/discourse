import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import ReviewableInsights from "discourse/components/reviewable/insights";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

function reviewableWithAuthorEmail(email) {
  return {
    reviewable_scores: [],
    topic: null,
    target_created_by: {
      id: 1,
      username: "staged_user",
      created_at: "2024-01-01T00:00:00.000Z",
      post_count: 2,
      email,
    },
  };
}

module("Integration | Component | Reviewable | Insights", function (hooks) {
  setupRenderingTest(hooks);

  test("renders the author's e-mail address as text, not markup", async function (assert) {
    const reviewable = reviewableWithAuthorEmail(
      `"<img src=x>"@attacker.example`
    );

    await render(
      <template><ReviewableInsights @reviewable={{reviewable}} /></template>
    );

    assert
      .dom(".review-insight__description img")
      .doesNotExist("does not treat the e-mail address as HTML");

    assert
      .dom(".review-insight__description")
      .includesText(`"<img src=x>"@attacker.example`, "shows the address");
  });

  test("renders an ordinary e-mail address unchanged", async function (assert) {
    const reviewable = reviewableWithAuthorEmail("staged@example.com");

    await render(
      <template><ReviewableInsights @reviewable={{reviewable}} /></template>
    );

    assert
      .dom(".review-insight__description")
      .includesText("staged@example.com", "shows the address");
  });
});
