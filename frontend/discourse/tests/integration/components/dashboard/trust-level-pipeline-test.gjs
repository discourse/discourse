import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import TrustLevelPipeline from "discourse/admin/components/dashboard/engagement/trust-level-pipeline";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module(
  "Integration | Component | Dashboard | TrustLevelPipeline",
  function (hooks) {
    setupRenderingTest(hooks);

    const row = (
      trust_level,
      count,
      share,
      promoted_in,
      signups = 0,
      demoted_in = 0
    ) => ({
      trust_level,
      count,
      share,
      promoted_in,
      signups,
      demoted_in,
    });

    const data = {
      total_members: 105_580,
      trend: { direction: "climbing", net: 72 },
      rows: [
        row(4, 25, 0.55, 0),
        row(3, 48, 0.85, 6, 0, 1),
        row(2, 4_800, 4.6, 12),
        row(1, 30_000, 28.5, 0, 0, 1),
        row(0, 69_000, 65.5, 0, 240, 5),
      ],
    };

    const rowAt = (index) =>
      [...document.querySelectorAll(".db-tl-pipeline__row")][index];

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

    test("renders a dropping trend pill in negative styling", async function (assert) {
      const negative = { ...data, trend: { direction: "dropping", net: 24 } };

      await render(
        <template><TrustLevelPipeline @data={{negative}} /></template>
      );

      assert.dom(".db-pill.--neg").hasText("-24 dropping");
    });

    test("links the section title to the trust_level_pipeline report", async function (assert) {
      await render(<template><TrustLevelPipeline @data={{data}} /></template>);

      assert
        .dom("a.db-section__row-block-title")
        .hasAttribute("href", /\/admin\/reports\/trust_level_pipeline/);
    });

    test("shows a stable pill in the label, not a flow, when a level had no movement", async function (assert) {
      await render(<template><TrustLevelPipeline @data={{data}} /></template>);

      assert.dom(".db-tl-pipeline__flow", rowAt(0)).doesNotExist();
      assert.dom(".db-tl-pipeline__label .db-pill", rowAt(0)).hasText("stable");
    });

    test("splits arrivals into a positive and a negative marker", async function (assert) {
      await render(<template><TrustLevelPipeline @data={{data}} /></template>);

      assert.dom(".db-delta.--pos", rowAt(1)).hasText("6");
      assert.dom(".db-delta.--neg", rowAt(1)).hasText("1");
    });

    test("shows a demotion into a level as a negative marker, never as a positive one", async function (assert) {
      await render(<template><TrustLevelPipeline @data={{data}} /></template>);

      assert.dom(".db-delta.--pos", rowAt(3)).doesNotExist();
      assert.dom(".db-delta.--neg", rowAt(3)).hasText("1");
    });

    test("draws a red bar when more members dropped in than climbed in", async function (assert) {
      await render(<template><TrustLevelPipeline @data={{data}} /></template>);

      assert.dom(".db-tl-pipeline__bar.--demoted", rowAt(3)).exists();
    });

    test("keeps the bar green when more members climbed in than dropped in", async function (assert) {
      await render(<template><TrustLevelPipeline @data={{data}} /></template>);

      assert.dom(".db-tl-pipeline__bar", rowAt(1)).exists();
      assert.dom(".db-tl-pipeline__bar.--demoted", rowAt(1)).doesNotExist();
    });

    test("shows the entry level's sign-ups inline as a plain count, never as a promotion", async function (assert) {
      await render(<template><TrustLevelPipeline @data={{data}} /></template>);

      assert
        .dom(".db-tl-pipeline__label .db-tl-pipeline__signups", rowAt(4))
        .hasText("+ 240 signups");
      assert.dom(".db-delta.--pos", rowAt(4)).doesNotExist();
    });

    test("still draws a directional bar on the entry level for real trust-level moves", async function (assert) {
      await render(<template><TrustLevelPipeline @data={{data}} /></template>);

      assert.dom(".db-tl-pipeline__flow", rowAt(4)).exists();
      assert.dom(".db-tl-pipeline__bar.--demoted", rowAt(4)).exists();
      assert
        .dom(".db-tl-pipeline__flow .db-delta.--neg", rowAt(4))
        .hasText("5");
    });

    test("an entry level above TL0 shows both its sign-ups and a promotion bar", async function (assert) {
      const raisedEntry = {
        ...data,
        rows: [
          row(4, 25, 0.55, 0),
          row(3, 48, 0.85, 6),
          row(2, 4_800, 4.6, 12, 300),
          row(1, 30_000, 28.5, 3),
          row(0, 69_000, 65.5, 0, 0, 5),
        ],
      };

      await render(
        <template><TrustLevelPipeline @data={{raisedEntry}} /></template>
      );

      assert.dom(".db-tl-pipeline__signups", rowAt(2)).hasText("+ 300 signups");
      assert.dom(".db-tl-pipeline__bar", rowAt(2)).exists();
      assert.dom(".db-tl-pipeline__bar.--demoted", rowAt(2)).doesNotExist();
      assert.dom(".db-delta.--pos", rowAt(2)).hasText("12");

      assert.dom(".db-delta.--pos", rowAt(3)).hasText("3");
    });
  }
);
