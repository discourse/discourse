import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import ReviewableInsights from "discourse/components/reviewable/insights";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | Reviewable | Insights", function (hooks) {
  setupRenderingTest(hooks);

  test("renders the author's email as text, not markup", async function (assert) {
    const email = `"<img src=x>"@example.com`;
    const reviewable = {
      target_created_by: { created_at: "2024-01-01T00:00:00.000Z", email },
    };

    await render(
      <template><ReviewableInsights @reviewable={{reviewable}} /></template>
    );

    assert.dom(".review-insight__description img").doesNotExist();
    assert.dom(".review-insight__description").includesText(email);
  });
});
