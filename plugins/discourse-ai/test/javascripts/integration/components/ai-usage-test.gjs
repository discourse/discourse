import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import AiUsage from "discourse/plugins/discourse-ai/discourse/components/ai-usage";

module("Integration | Component | AiUsage", function (hooks) {
  setupRenderingTest(hooks);

  test("shows all users in a single table", async function (assert) {
    await renderUsage(24);

    assert
      .dom(".ai-usage__users-table")
      .exists({ count: 1 }, "renders one users table");
    assert
      .dom(".ai-usage__users-row")
      .exists({ count: 24 }, "renders every user");
  });

  test("splits larger user lists across two tables", async function (assert) {
    await renderUsage(25);

    assert
      .dom(".ai-usage__users-table")
      .exists({ count: 2 }, "renders two users tables");
    assert
      .dom(".ai-usage__users-row")
      .exists({ count: 25 }, "renders every user");
  });
});

async function renderUsage(userCount) {
  const model = {
    features: [],
    models: [],
    summary: {},
    users: Array.from({ length: userCount }, (_, index) => ({
      avatar_template: "/letter_avatar_proxy/v4/letter/u/45deac/{size}.png",
      username: `user-${index}`,
      usage_count: 1,
      total_tokens: 1,
      total_spending: 0,
    })),
  };
  const queryParams = {};

  pretender.get("/admin/plugins/discourse-ai/ai-usage-report.json", () =>
    response(model)
  );

  await render(
    <template>
      <AiUsage @model={{model}} @queryParams={{queryParams}} />
    </template>
  );
}
