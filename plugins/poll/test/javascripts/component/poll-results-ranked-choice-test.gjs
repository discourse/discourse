import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";
import PollResultsRankedChoice from "discourse/plugins/poll/discourse/components/poll-results-ranked-choice";

const RANKED_CHOICE_OUTCOME = {
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

module("Poll | Component | poll-results-ranked-choice", function (hooks) {
  setupRenderingTest(hooks);

  test("Renders the ranked choice results component correctly", async function (assert) {
    const self = this;

    this.setProperties({
      rankedChoiceOutcome: RANKED_CHOICE_OUTCOME,
    });

    await render(
      <template>
        <PollResultsRankedChoice
          @rankedChoiceOutcome={{self.rankedChoiceOutcome}}
        />
      </template>
    );

    assert
      .dom("table.poll-results-ranked-choice tr")
      .exists({ count: 3 }, "there are two rounds of ranked choice");

    assert.dom("span.poll-results-ranked-choice-info").hasText(
      i18n("poll.ranked_choice.winner", {
        count: this.rankedChoiceOutcome.round_activity.length,
        winner: this.rankedChoiceOutcome.winning_candidate.html,
      }),
      "displays the winner information"
    );
  });

  test("Renders the ranked choice results component without error when outcome data is empty", async function (assert) {
    const self = this;

    this.rankedChoiceOutcome = null;

    await render(
      <template>
        <PollResultsRankedChoice
          @rankedChoiceOutcome={{self.rankedChoiceOutcome}}
        />
      </template>
    );

    assert
      .dom("table.poll-results-ranked-choice tr")
      .exists(
        { count: 1 },
        "there are no rounds of ranked choice displayed, only the header"
      );
  });
});
