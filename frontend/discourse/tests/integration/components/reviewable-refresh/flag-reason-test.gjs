import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import ReviewableFlagReason from "discourse/components/reviewable-refresh/flag-reason";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module(
  "Integration | Component | reviewable-refresh | flag-reason",
  function (hooks) {
    setupRenderingTest(hooks);

    test("renders with basic arguments", async function (assert) {
      const score = { type: "spam", title: "This is spam", count: 3 };

      await render(
        <template><ReviewableFlagReason @score={{score}} /></template>
      );

      assert
        .dom(".review-item__flag-reason")
        .exists("renders the flag reason container");
      assert
        .dom(".review-item__flag-reason")
        .containsText("This is spam", "displays the title");
      assert
        .dom(".review-item__flag-count")
        .exists("renders the flag count element");
      assert
        .dom(".review-item__flag-count")
        .containsText("x3", "displays the count value formatted as xN");
    });

    test("does not render count when invalid", async function (assert) {
      const countScenarios = [
        { count: 0, title: "Zero count", description: "count is 0" },
        { count: 1, title: "Single count", description: "count is 1" },
        {
          count: undefined,
          title: "Undefined count",
          description: "count is not provided",
        },
        {
          count: -1,
          title: "Negative count",
          description: "count is negative",
        },
      ];

      for (const { count, title, description } of countScenarios) {
        const score = { type: "spam", title, count };

        await render(
          <template><ReviewableFlagReason @score={{score}} /></template>
        );

        assert
          .dom(".review-item__flag-count")
          .doesNotExist(`does not render count element when ${description}`);
        assert
          .dom(".review-item__flag-reason")
          .containsText(title, `still displays the title when ${description}`);
      }
    });

    test("renders title even when empty string", async function (assert) {
      const score = { type: "spam", title: "", count: 2 };

      await render(
        <template><ReviewableFlagReason @score={{score}} /></template>
      );

      assert
        .dom(".review-item__flag-reason")
        .exists("renders the flag reason container");
      assert
        .dom(".review-item__flag-reason")
        .hasText("x2", "shows the count when title is empty");
    });
  }
);
