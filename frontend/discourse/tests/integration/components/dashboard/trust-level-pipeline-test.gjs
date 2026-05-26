import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import TrustLevelPipeline from "discourse/admin/components/dashboard/engagement/trust-level-pipeline";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module(
  "Integration | Component | Dashboard | TrustLevelPipeline",
  function (hooks) {
    setupRenderingTest(hooks);

    const data = {
      total_members: 105_580,
      trend: { direction: "climbing", net: 72 },
      rows: [
        { trust_level: 4, count: 25, share: 0.55, moves_in: 4, moves_out: 0 },
        { trust_level: 3, count: 48, share: 0.85, moves_in: 14, moves_out: 2 },
        {
          trust_level: 2,
          count: 4_800,
          share: 4.6,
          moves_in: 42,
          moves_out: 12,
        },
        {
          trust_level: 1,
          count: 30_000,
          share: 28.5,
          moves_in: 50,
          moves_out: 18,
        },
        {
          trust_level: 0,
          count: 69_000,
          share: 65.5,
          moves_in: 0,
          moves_out: 0,
        },
      ],
    };

    test("renders one row per trust level in descending order", async function (assert) {
      await render(<template><TrustLevelPipeline @data={{data}} /></template>);

      assert.dom(".db-tl-pipeline__row").exists({ count: 5 });

      const names = [...document.querySelectorAll(".db-tl-pipeline__name")].map(
        (el) => el.textContent.trim()
      );
      assert.deepEqual(names, ["Leader", "Regular", "Member", "Basic", "New"]);
    });

    test("renders the climbing trend pill with positive styling", async function (assert) {
      await render(<template><TrustLevelPipeline @data={{data}} /></template>);

      assert.dom(".db-pill.--pos").hasText("+72 climbing");
    });

    test("links the section title to the trust_level_pipeline report", async function (assert) {
      await render(<template><TrustLevelPipeline @data={{data}} /></template>);

      assert
        .dom("a.db-section__row-block-title")
        .hasAttribute("href", /\/admin\/reports\/trust_level_pipeline/);
    });

    test("hides the bars section entirely when a row has no movement on either side", async function (assert) {
      await render(<template><TrustLevelPipeline @data={{data}} /></template>);

      const newRow = [...document.querySelectorAll(".db-tl-pipeline__row")].at(
        -1
      );
      assert.dom(".db-tl-pipeline__bars", newRow).doesNotExist();
      assert.dom(".db-pill", newRow).doesNotExist();
    });

    test("shows a stable pill on the side that has no movement when the other side does", async function (assert) {
      const oneSided = {
        ...data,
        rows: data.rows.map((r) =>
          r.trust_level === 4 ? { ...r, moves_in: 4, moves_out: 0 } : r
        ),
      };

      await render(
        <template><TrustLevelPipeline @data={{oneSided}} /></template>
      );

      const leaderRow = document.querySelector(".db-tl-pipeline__row");
      assert
        .dom(".db-tl-pipeline__bar-out .db-pill", leaderRow)
        .hasText("stable");
      assert.dom(".db-tl-pipeline__delta--in", leaderRow).includesText("4");
    });

    test("renders moves_in and moves_out deltas with the count", async function (assert) {
      await render(<template><TrustLevelPipeline @data={{data}} /></template>);

      assert.dom(".db-tl-pipeline__delta--in").includesText("4");
      assert.dom(".db-tl-pipeline__delta--out").exists();
    });

    test("renders a dropping trend pill in negative styling", async function (assert) {
      const negative = {
        ...data,
        trend: { direction: "dropping", net: 24 },
      };

      await render(
        <template><TrustLevelPipeline @data={{negative}} /></template>
      );

      assert.dom(".db-pill.--neg").hasText("-24 dropping");
    });
  }
);
