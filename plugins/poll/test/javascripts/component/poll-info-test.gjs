import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";
import PollInfo from "discourse/plugins/poll/discourse/components/poll-info";

const OPTIONS = [
  { id: "1ddc47be0d2315b9711ee8526ca9d83f", html: "This", votes: 2, rank: 0 },
  { id: "70e743697dac09483d7b824eaadb91e1", html: "That", votes: 3, rank: 0 },
  { id: "6c986ebcde3d5822a6e91a695c388094", html: "Other", votes: 5, rank: 0 },
];

module("Component | PollInfo", function (hooks) {
  setupRenderingTest(hooks);

  test("public multiple poll with results anytime", async function (assert) {
    this.isMultiple = true;
    this.min = 1;
    this.max = 2;
    this.options = OPTIONS;
    this.closesAt = null;
    this.closed = false;
    this.results = [];
    this.showResults = false;
    this.postUserId = 59;
    this.isPublic = true;
    this.hasVoted = true;
    this.voters = [];

    await render(
      <template>
        <PollInfo
          @closed={{this.closed}}
          @closesAt={{this.closesAt}}
          @hasVoted={{this.hasVoted}}
          @isMultiple={{this.isMultiple}}
          @isPublic={{this.isPublic}}
          @max={{this.max}}
          @min={{this.min}}
          @options={{this.options}}
          @postUserId={{this.postUserId}}
          @results={{this.results}}
          @showResults={{this.showResults}}
          @voters={{this.voters}}
        />
      </template>
    );

    assert.dom(".poll-info_instructions li.multiple-help-text").hasText(
      i18n("poll.multiple.help.up_to_max_options", {
        count: this.max,
      }).replace(/<\/?[^>]+(>|$)/g, ""),
      "displays the multiple help text"
    );

    assert
      .dom(".poll-info_instructions li.is-public")
      .hasText(
        i18n("poll.public.title").replace(/<\/?[^>]+(>|$)/g, ""),
        "displays the public label"
      );
  });

  test("public multiple poll with results only shown on vote", async function (assert) {
    this.isMultiple = true;
    this.min = 1;
    this.max = 2;
    this.options = OPTIONS;
    this.closesAt = null;
    this.closed = false;
    this.results = "on_vote";
    this.showResults = false;
    this.postUserId = 59;
    this.isPublic = true;
    this.hasVoted = false;
    this.voters = [];

    await render(
      <template>
        <PollInfo
          @closed={{this.closed}}
          @closesAt={{this.closesAt}}
          @hasVoted={{this.hasVoted}}
          @isMultiple={{this.isMultiple}}
          @isPublic={{this.isPublic}}
          @max={{this.max}}
          @min={{this.min}}
          @options={{this.options}}
          @postUserId={{this.postUserId}}
          @results={{this.results}}
          @showResults={{this.showResults}}
          @voters={{this.voters}}
        />
      </template>
    );

    assert.dom(".poll-info_instructions li.multiple-help-text").hasText(
      i18n("poll.multiple.help.up_to_max_options", {
        count: this.max,
      }).replace(/<\/?[^>]+(>|$)/g, ""),
      "displays the multiple help text"
    );

    assert
      .dom(".poll-info_instructions li.results-on-vote span")
      .hasText(
        i18n("poll.results.vote.title").replace(/<\/?[^>]+(>|$)/g, ""),
        "displays the results on vote label"
      );

    assert
      .dom(".poll-info_instructions li.is-public")
      .hasText(
        i18n("poll.public.title").replace(/<\/?[^>]+(>|$)/g, ""),
        "displays the public label"
      );
  });

  test("displays who closed the poll", async function (assert) {
    this.options = OPTIONS;
    this.closesAt = null;
    this.closed = true;
    this.closedBy = { username: "jane" };
    this.results = [];
    this.showResults = false;
    this.postUserId = 59;
    this.isPublic = false;
    this.hasVoted = false;
    this.voters = [];

    await render(
      <template>
        <PollInfo
          @closed={{this.closed}}
          @closedBy={{this.closedBy}}
          @closesAt={{this.closesAt}}
          @hasVoted={{this.hasVoted}}
          @isPublic={{this.isPublic}}
          @options={{this.options}}
          @postUserId={{this.postUserId}}
          @results={{this.results}}
          @showResults={{this.showResults}}
          @voters={{this.voters}}
        />
      </template>
    );

    assert
      .dom(".poll-info_instructions li.poll-info_closed-by span")
      .hasText(i18n("poll.closed_by", { username: "jane" }));
  });
});
