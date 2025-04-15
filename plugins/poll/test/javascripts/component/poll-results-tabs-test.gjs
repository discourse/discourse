import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import PollResultsTabs from "discourse/plugins/poll/discourse/components/poll-results-tabs";

const TWO_OPTIONS = [
  {
    id: "1ddc47be0d2315b9711ee8526ca9d83f",
    html: "Team Yellow",
    votes: 5,
    rank: 2,
  },
  {
    id: "70e743697dac09483d7b824eaadb91e1",
    html: "Team Blue",
    votes: 4,
    rank: 1,
  },
];

const RANKED_CHOICE_OUTCOME = {
  tied: false,
  tied_candidates: null,
  winner: true,
  winning_candidate: {
    digest: "70e743697dac09483d7b824eaadb91e1",
    html: "Team Blue",
  },
  round_activity: [
    {
      round: 1,
      eliminated: [
        { digest: "1ddc47be0d2315b9711ee8526ca9d83f", html: "Team Yellow" },
      ],
      majority: null,
    },
    {
      round: 2,
      majority: [
        { digest: "70e743697dac09483d7b824eaadb91e1", html: "Team Blue" },
      ],
      eliminated: null,
    },
  ],
};

const PRELOADEDVOTERS = {
  db753fe0bc4e72869ac1ad8765341764: [
    {
      id: 1,
      username: "bianca",
      name: null,
      avatar_template: "/letter_avatar_proxy/v4/letter/b/3be4f8/{size}.png",
    },
  ],
};

module("Poll | Component | poll-results-tabs", function (hooks) {
  setupRenderingTest(hooks);

  test("Renders one tab for non-ranked-choice poll", async function (assert) {
    const self = this;

    this.setProperties({
      options: TWO_OPTIONS,
      pollName: "Two Choice Poll",
      pollType: "single",
      isPublic: true,
      isRankedChoice: false,
      postId: 123,
      vote: ["1ddc47be0d2315b9711ee8526ca9d83f"],
      voters: PRELOADEDVOTERS,
      votersCount: 9,
      fetchVoters: () => {},
    });

    await render(
      <template>
        <PollResultsTabs
          @options={{self.options}}
          @pollName={{self.pollName}}
          @pollType={{self.pollType}}
          @isPublic={{self.isPublic}}
          @isRankedChoice={{self.isRankedChoice}}
          @postId={{self.postId}}
          @vote={{self.vote}}
          @voters={{self.voters}}
          @votersCount={{self.votersCount}}
          @fetchVoters={{self.fetchVoters}}
        />
      </template>
    );

    assert.dom("li.tab").exists({ count: 1 });
  });

  test("Renders two tabs for public ranked choice poll", async function (assert) {
    const self = this;

    this.setProperties({
      options: TWO_OPTIONS,
      pollName: "Two Choice Poll",
      pollType: "ranked_choice",
      isPublic: true,
      isRankedChoice: true,
      rankedChoiceOutcome: RANKED_CHOICE_OUTCOME,
      postId: 123,
      vote: ["1ddc47be0d2315b9711ee8526ca9d83f"],
      voters: PRELOADEDVOTERS,
      votersCount: 9,
      fetchVoters: () => {},
    });

    await render(
      <template>
        <PollResultsTabs
          @options={{self.options}}
          @pollName={{self.pollName}}
          @pollType={{self.pollType}}
          @isPublic={{self.isPublic}}
          @isRankedChoice={{self.isRankedChoice}}
          @rankedChoiceOutcome={{self.rankedChoiceOutcome}}
          @postId={{self.postId}}
          @vote={{self.vote}}
          @voters={{self.voters}}
          @votersCount={{self.votersCount}}
          @fetchVoters={{self.fetchVoters}}
        />
      </template>
    );

    assert.dom("li.tab").exists({ count: 2 });
  });

  test("Renders one tab for private ranked choice poll", async function (assert) {
    const self = this;

    this.setProperties({
      options: TWO_OPTIONS,
      pollName: "Two Choice Poll",
      pollType: "ranked_choice",
      isPublic: false,
      isRankedChoice: true,
      rankedChoiceOutcome: RANKED_CHOICE_OUTCOME,
      postId: 123,
      vote: ["1ddc47be0d2315b9711ee8526ca9d83f"],
      voters: PRELOADEDVOTERS,
      votersCount: 9,
      fetchVoters: () => {},
    });

    await render(
      <template>
        <PollResultsTabs
          @options={{self.options}}
          @pollName={{self.pollName}}
          @pollType={{self.pollType}}
          @isPublic={{self.isPublic}}
          @isRankedChoice={{self.isRankedChoice}}
          @rankedChoiceOutcome={{self.rankedChoiceOutcome}}
          @postId={{self.postId}}
          @vote={{self.vote}}
          @voters={{self.voters}}
          @votersCount={{self.votersCount}}
          @fetchVoters={{self.fetchVoters}}
        />
      </template>
    );

    assert.dom("li.tab").exists({ count: 1 });
  });
});
