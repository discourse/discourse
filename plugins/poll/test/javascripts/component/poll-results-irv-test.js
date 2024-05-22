import { render } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { count, query } from "discourse/tests/helpers/qunit-helpers";
import I18n from "I18n";

const IRV_OUTCOME = {
  tied: false,
  tied_candidates: null,
  winner: true,
  winning_candidate: {
    digest: "c8678f4ce846ad5415278ff7ecadf3a6",
    html: "Team Blue",
  },
  round_activity: [
    {
      round: 1,
      eliminated: [
        { digest: "8bbb100d504298ad65a2604e99d5ba82", html: "Team Yellow" },
      ],
      majority: null,
    },
    {
      round: 2,
      majority: [
        { digest: "c8678f4ce846ad5415278ff7ecadf3a6", html: "Team Blue" },
      ],
      eliminated: null,
    },
  ],
};

module("Poll | Component | poll-results-irv", function (hooks) {
  setupRenderingTest(hooks);

  test("Renders the IRV results Component correctly", async function (assert) {
    this.setProperties({
      irvOutcome: IRV_OUTCOME,
    });

    await render(hbs`<PollResultsIrv @irvOutcome={{this.irvOutcome}} />`);

    assert.strictEqual(
      count("table.poll-results-irv tr"),
      3,
      "there are two rounds of IRV"
    );

    assert.strictEqual(
      query("span.poll-results-irv-info").textContent.trim(),
      I18n.t("poll.irv.winner", {
        count: this.irvOutcome.round_activity.length,
        winner: this.irvOutcome.winning_candidate.html,
      }),
      "displays the winner information"
    );
  });
});
