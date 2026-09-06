import { render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import SupportTopicOutcomes from "discourse/plugins/discourse-solved/admin/components/dashboard/support/topic-outcomes";

module(
  "Integration | Component | Dashboard | Support | SupportTopicOutcomes",
  function (hooks) {
    setupRenderingTest(hooks);

    test("links each row to the topic list using the query it was given", async function (assert) {
      const outcomes = { resolved: 4, in_progress: 2, unanswered: 1 };
      const queries = {
        resolved: { q: "status:solved created-after:2026-04-01" },
        in_progress: {
          q: "status:unsolved posts-min:2 created-after:2026-04-01",
        },
        unanswered: {
          q: "status:unsolved status:noreplies created-after:2026-04-01",
        },
      };

      await render(
        <template>
          <SupportTopicOutcomes @outcomes={{outcomes}} @queries={{queries}} />
        </template>
      );

      assert
        .dom(".db-support-outcomes__row:nth-child(1) a")
        .hasAttribute(
          "href",
          `/filter?q=${encodeURIComponent(queries.resolved.q)}`,
          "resolved links to its given query"
        )
        .hasText("Resolved", "resolved shows its label");

      await triggerEvent(
        ".db-support-outcomes__row:nth-child(1) .fk-d-tooltip__trigger",
        "pointermove"
      );
      assert
        .dom(".fk-d-tooltip__content")
        .hasText(
          "The number of topics that were marked solved.",
          "resolved keeps its tooltip"
        );

      assert
        .dom(".db-support-outcomes__row:nth-child(2) a")
        .hasAttribute(
          "href",
          `/filter?q=${encodeURIComponent(queries.in_progress.q)}`,
          "in progress links to its given query"
        );

      assert
        .dom(".db-support-outcomes__row:nth-child(3) a")
        .hasAttribute(
          "href",
          `/filter?q=${encodeURIComponent(queries.unanswered.q)}`,
          "unanswered links to its given query"
        );

      assert
        .dom(
          ".db-support-outcomes__row:nth-child(1) .db-support-outcomes__share"
        )
        .hasText("4", "still shows the count next to the link");
    });

    test("keeps the bar graphic hidden from assistive tech while the label and count stay exposed", async function (assert) {
      const outcomes = { resolved: 1, in_progress: 0, unanswered: 0 };

      await render(
        <template><SupportTopicOutcomes @outcomes={{outcomes}} /></template>
      );

      assert
        .dom(".db-support-outcomes__bars")
        .doesNotHaveAttribute("role", "no longer collapsed into a single img");
      assert
        .dom(".db-support-outcomes__track")
        .hasAttribute(
          "aria-hidden",
          "true",
          "the decorative bar is hidden from assistive tech"
        );
      assert
        .dom(".db-support-outcomes__share")
        .doesNotHaveAttribute(
          "aria-hidden",
          "the count stays exposed to assistive tech"
        );
      assert
        .dom(".db-support-outcomes__label")
        .exists({ count: 3 }, "each row renders a focusable label link");
    });

    test("falls back to an empty query when none is provided for a row", async function (assert) {
      const outcomes = { resolved: 1, in_progress: 0, unanswered: 0 };

      await render(
        <template><SupportTopicOutcomes @outcomes={{outcomes}} /></template>
      );

      assert
        .dom(".db-support-outcomes__row:nth-child(1) a")
        .hasAttribute(
          "href",
          "/filter",
          "still links to the filter page without a query"
        );
    });
  }
);
