import EmberObject from "@ember/object";
import { trackedObject } from "@ember/reactive/collections";
import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { i18n } from "discourse-i18n";
import Poll from "discourse/plugins/poll/discourse/components/poll";

let requests = 0;

module("Component | Poll", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    pretender.put("/polls/vote", () => {
      ++requests;
      return response({
        poll: {
          name: "poll",
          type: "regular",
          status: "open",
          results: "always",
          options: [
            {
              id: "1f972d1df351de3ce35a787c89faad29",
              html: "yes",
              votes: 1,
            },
            {
              id: "d7ebc3a9beea2e680815a1e4f57d6db6",
              html: "no",
              votes: 0,
            },
          ],
          voters: 1,
          chart_type: "bar",
        },
        vote: ["1f972d1df351de3ce35a787c89faad29"],
      });
    });
  });

  test("valid ranks with which you can vote", async function (assert) {
    this.setProperties({
      post: EmberObject.create({
        id: 42,
        topic: {
          archived: false,
        },
        user_id: 29,
        polls_votes: {
          poll: [
            {
              digest: "1f972d1df351de3ce35a787c89faad29",
              rank: 1,
            },
            {
              digest: "d7ebc3a9beea2e680815a1e4f57d6db6",
              rank: 2,
            },
            {
              digest: "6c986ebcde3d5822a6e91a695c388094",
              rank: 3,
            },
          ],
        },
      }),
      poll: trackedObject({
        name: "poll",
        type: "ranked_choice",
        status: "open",
        results: "on_close",
        options: [
          {
            id: "1f972d1df351de3ce35a787c89faad29",
            html: "this",
            votes: 0,
            rank: 1,
          },
          {
            id: "d7ebc3a9beea2e680815a1e4f57d6db6",
            html: "that",
            votes: 0,
            rank: 2,
          },
          {
            id: "6c986ebcde3d5822a6e91a695c388094",
            html: "other",
            votes: 0,
            rank: 3,
          },
        ],
        voters: 0,
        chart_type: "bar",
      }),
    });

    await render(
      <template><Poll @post={{this.post}} @poll={{this.poll}} /></template>
    );

    assert.dom(".poll-buttons .cast-votes:disabled").doesNotExist();
    assert.dom(".poll-buttons .cast-votes").exists();
  });

  test("invalid ranks with which you cannot vote", async function (assert) {
    this.setProperties({
      post: EmberObject.create({
        id: 42,
        topic: {
          archived: false,
        },
        user_id: 29,
      }),
      poll: trackedObject({
        name: "poll",
        type: "ranked_choice",
        status: "open",
        results: "always",
        options: [
          {
            id: "1f972d1df351de3ce35a787c89faad29",
            html: "this",
            votes: 0,
            rank: 0,
          },
          {
            id: "d7ebc3a9beea2e680815a1e4f57d6db6",
            html: "that",
            votes: 0,
            rank: 0,
          },
          {
            id: "6c986ebcde3d5822a6e91a695c388094",
            html: "other",
            votes: 0,
            rank: 0,
          },
        ],
        voters: 0,
        chart_type: "bar",
      }),
    });

    await render(
      <template><Poll @post={{this.post}} @poll={{this.poll}} /></template>
    );

    await click(
      ".ranked-choice-poll-option[data-poll-option-id='1f972d1df351de3ce35a787c89faad29'] button",
      "open dropdown"
    );

    assert
      .dom(".dropdown-menu__item:nth-child(2)")
      .hasText(`1 ${i18n("poll.options.ranked_choice.highest_priority")}`);

    await click(
      ".dropdown-menu__item:nth-child(2) button",
      "select 1st priority"
    );

    assert.dom(".poll-buttons .cast-votes:disabled").doesNotExist();
    assert.dom(".poll-buttons .cast-votes").exists();

    await click(
      ".ranked-choice-poll-option[data-poll-option-id='1f972d1df351de3ce35a787c89faad29'] button",
      "open dropdown"
    );

    await click(".dropdown-menu__item:nth-child(1) button", "select Abstain");

    assert.dom(".poll-buttons .cast-votes:disabled").exists();
  });

  test("shows vote", async function (assert) {
    this.setProperties({
      post: EmberObject.create({
        id: 42,
        topic: {
          archived: false,
        },
        user_id: 29,
      }),
      poll: trackedObject({
        name: "poll",
        type: "regular",
        status: "closed",
        results: "always",
        options: [
          { id: "1f972d1df351de3ce35a787c89faad29", html: "yes", votes: 1 },
          { id: "d7ebc3a9beea2e680815a1e4f57d6db6", html: "no", votes: 0 },
        ],
        voters: 1,
        chart_type: "bar",
      }),
    });

    await render(
      <template><Poll @post={{this.post}} @poll={{this.poll}} /></template>
    );

    assert.dom(".results li:nth-of-type(1) .option p").hasText("100% yes");
    assert.dom(".results li:nth-of-type(2) .option p").hasText("0% no");
  });

  test("does not show results after voting when results are to be shown only on closed", async function (assert) {
    this.setProperties({
      post: EmberObject.create({
        id: 42,
        topic: {
          archived: false,
        },
        user_id: 29,
      }),
      poll: trackedObject({
        name: "poll",
        type: "regular",
        status: "open",
        results: "on_close",
        options: [
          { id: "1f972d1df351de3ce35a787c89faad29", html: "yes" },
          { id: "d7ebc3a9beea2e680815a1e4f57d6db6", html: "no" },
        ],
        voters: 1,
        chart_type: "bar",
      }),
    });

    await render(
      <template><Poll @post={{this.post}} @poll={{this.poll}} /></template>
    );

    assert.dom("ul.options").exists("options are shown");
    assert.dom("ul.results").doesNotExist("results are not shown");
  });

  test("does not render an empty ranked choice outcome to a non-staff voter on staff_only polls", async function (assert) {
    this.setProperties({
      post: EmberObject.create({
        id: 42,
        topic: {
          archived: false,
        },
        user_id: 29,
        polls_votes: {
          poll: [
            { digest: "1f972d1df351de3ce35a787c89faad29", rank: 1 },
            { digest: "d7ebc3a9beea2e680815a1e4f57d6db6", rank: 2 },
          ],
        },
      }),
      poll: trackedObject({
        name: "poll",
        type: "ranked_choice",
        status: "open",
        results: "staff_only",
        options: [
          { id: "1f972d1df351de3ce35a787c89faad29", html: "this", rank: 1 },
          { id: "d7ebc3a9beea2e680815a1e4f57d6db6", html: "that", rank: 2 },
        ],
        voters: 1,
        chart_type: "bar",
        // no ranked_choice_outcome — the server withholds it from non-staff
      }),
    });

    await render(
      <template><Poll @post={{this.post}} @poll={{this.poll}} /></template>
    );

    assert
      .dom("table.poll-results-ranked-choice")
      .doesNotExist("the empty outcome table is not rendered");
    assert
      .dom(".results-staff-only")
      .exists("the staff-only results notice is shown instead");
    assert
      .dom(".ranked-choice-poll-option")
      .exists("the ballot options are shown to the voter");
  });

  test("can vote", async function (assert) {
    this.setProperties({
      post: EmberObject.create({
        id: 42,
        topic: {
          archived: false,
        },
        user_id: 29,
      }),
      poll: trackedObject({
        name: "poll",
        type: "regular",
        status: "open",
        results: "always",
        options: [
          { id: "1f972d1df351de3ce35a787c89faad29", html: "yes", votes: 0 },
          { id: "d7ebc3a9beea2e680815a1e4f57d6db6", html: "no", votes: 0 },
        ],
        voters: 0,
        chart_type: "bar",
      }),
    });

    await render(
      <template><Poll @post={{this.post}} @poll={{this.poll}} /></template>
    );

    requests = 0;

    await click(
      "li[data-poll-option-id='1f972d1df351de3ce35a787c89faad29'] button"
    );
    assert.strictEqual(requests, 1);
    assert.dom(".chosen").exists({ count: 1 });

    await click(".toggle-results");
    assert
      .dom("li[data-poll-option-id='1f972d1df351de3ce35a787c89faad29']")
      .exists({ count: 1 });
  });

  test("cannot vote if not member of the right group", async function (assert) {
    this.setProperties({
      post: EmberObject.create({
        id: 42,
        topic: {
          archived: false,
        },
        user_id: 29,
      }),
      poll: trackedObject({
        name: "poll",
        type: "regular",
        status: "open",
        results: "always",
        options: [
          { id: "1f972d1df351de3ce35a787c89faad29", html: "yes", votes: 0 },
          { id: "d7ebc3a9beea2e680815a1e4f57d6db6", html: "no", votes: 0 },
        ],
        voters: 0,
        chart_type: "bar",
        groups: "foo",
      }),
    });

    await render(
      <template><Poll @post={{this.post}} @poll={{this.poll}} /></template>
    );

    requests = 0;

    await click(
      "li[data-poll-option-id='1f972d1df351de3ce35a787c89faad29'] button"
    );
    assert
      .dom(".poll-container .alert")
      .hasText(i18n("poll.results.groups.title", { groups: "foo" }));
    assert.strictEqual(requests, 0);
    assert.dom(".chosen").doesNotExist();
  });

  test("keeps the voting view after the poll component is re-rendered", async function (assert) {
    this.setProperties({
      post: EmberObject.create({
        id: 42,
        topic: {
          archived: false,
        },
        user_id: 29,
        polls_votes: {
          poll: ["1f972d1df351de3ce35a787c89faad29"],
        },
      }),
      poll: trackedObject({
        name: "poll",
        type: "multiple",
        status: "open",
        results: "always",
        min: 1,
        max: 2,
        options: [
          { id: "1f972d1df351de3ce35a787c89faad29", html: "yes", votes: 1 },
          { id: "d7ebc3a9beea2e680815a1e4f57d6db6", html: "no", votes: 0 },
        ],
        voters: 1,
        chart_type: "bar",
      }),
    });

    await render(
      <template><Poll @post={{this.post}} @poll={{this.poll}} /></template>
    );

    assert.dom("ul.results").exists("results are shown for the saved vote");
    assert.dom(".poll-buttons .cast-votes").doesNotExist();

    await click(".poll-buttons .toggle-results");

    assert
      .dom("ul.options")
      .exists("clicking the button shows the voting view");
    assert.dom(".poll-buttons .cast-votes").exists();

    await render(
      <template><Poll @post={{this.post}} @poll={{this.poll}} /></template>
    );

    assert
      .dom("ul.options")
      .exists("the voting view survives the component being re-rendered");
    assert.dom("ul.results").doesNotExist();
    assert.dom(".poll-buttons .cast-votes").exists();
  });

  test("keeps an uncommitted selection after the poll component is re-rendered", async function (assert) {
    this.setProperties({
      post: EmberObject.create({
        id: 42,
        topic: {
          archived: false,
        },
        user_id: 29,
      }),
      poll: trackedObject({
        name: "poll",
        type: "multiple",
        status: "open",
        results: "always",
        min: 1,
        max: 2,
        options: [
          { id: "1f972d1df351de3ce35a787c89faad29", html: "yes", votes: 0 },
          { id: "d7ebc3a9beea2e680815a1e4f57d6db6", html: "no", votes: 0 },
        ],
        voters: 0,
        chart_type: "bar",
      }),
    });

    await render(
      <template><Poll @post={{this.post}} @poll={{this.poll}} /></template>
    );

    await click(
      "li[data-poll-option-id='1f972d1df351de3ce35a787c89faad29'] button"
    );
    assert
      .dom(
        "li[data-poll-option-id='1f972d1df351de3ce35a787c89faad29'] .d-icon-far-square-check"
      )
      .exists("the option is selected but not yet cast");

    await render(
      <template><Poll @post={{this.post}} @poll={{this.poll}} /></template>
    );

    assert
      .dom(
        "li[data-poll-option-id='1f972d1df351de3ce35a787c89faad29'] .d-icon-far-square-check"
      )
      .exists("the uncommitted selection survives the re-render");
    assert.dom(".poll-buttons .cast-votes").exists();
  });

  test("ignores a stale hidden-results toggle on a closed poll", async function (assert) {
    this.setProperties({
      post: EmberObject.create({
        id: 42,
        topic: {
          archived: false,
        },
        user_id: 29,
        polls_votes: {
          poll: ["1f972d1df351de3ce35a787c89faad29"],
        },
      }),
      poll: trackedObject({
        name: "poll",
        type: "multiple",
        status: "closed",
        results: "always",
        min: 1,
        max: 2,
        showResultsToggle: false,
        options: [
          { id: "1f972d1df351de3ce35a787c89faad29", html: "yes", votes: 1 },
          { id: "d7ebc3a9beea2e680815a1e4f57d6db6", html: "no", votes: 0 },
        ],
        voters: 1,
        chart_type: "bar",
      }),
    });

    await render(
      <template><Poll @post={{this.post}} @poll={{this.poll}} /></template>
    );

    assert
      .dom("ul.results")
      .exists("a closed poll shows results despite a stale hidden toggle");
    assert.dom("ul.options").doesNotExist();
  });

  test("does not mutate the saved vote when toggling an uncast option", async function (assert) {
    this.setProperties({
      post: EmberObject.create({
        id: 42,
        topic: {
          archived: false,
        },
        user_id: 29,
        polls_votes: {
          poll: ["1f972d1df351de3ce35a787c89faad29"],
        },
      }),
      poll: trackedObject({
        name: "poll",
        type: "multiple",
        status: "open",
        results: "always",
        min: 1,
        max: 2,
        showResultsToggle: false,
        options: [
          { id: "1f972d1df351de3ce35a787c89faad29", html: "yes", votes: 1 },
          { id: "d7ebc3a9beea2e680815a1e4f57d6db6", html: "no", votes: 0 },
        ],
        voters: 1,
        chart_type: "bar",
      }),
    });

    await render(
      <template><Poll @post={{this.post}} @poll={{this.poll}} /></template>
    );

    await click(
      "li[data-poll-option-id='d7ebc3a9beea2e680815a1e4f57d6db6'] button"
    );

    assert.deepEqual(
      this.post.polls_votes.poll,
      ["1f972d1df351de3ce35a787c89faad29"],
      "toggling an uncast option leaves the saved vote array untouched"
    );
  });

  test("keeps a ranked-choice selection after the poll component is re-rendered", async function (assert) {
    this.setProperties({
      post: EmberObject.create({
        id: 42,
        topic: {
          archived: false,
        },
        user_id: 29,
      }),
      poll: trackedObject({
        name: "poll",
        type: "ranked_choice",
        status: "open",
        results: "always",
        options: [
          {
            id: "1f972d1df351de3ce35a787c89faad29",
            html: "this",
            votes: 0,
            rank: 0,
          },
          {
            id: "d7ebc3a9beea2e680815a1e4f57d6db6",
            html: "that",
            votes: 0,
            rank: 0,
          },
          {
            id: "6c986ebcde3d5822a6e91a695c388094",
            html: "other",
            votes: 0,
            rank: 0,
          },
        ],
        voters: 0,
        chart_type: "bar",
      }),
    });

    await render(
      <template><Poll @post={{this.post}} @poll={{this.poll}} /></template>
    );

    await click(
      ".ranked-choice-poll-option[data-poll-option-id='1f972d1df351de3ce35a787c89faad29'] button"
    );
    await click(".dropdown-menu__item:nth-child(2) button");

    assert
      .dom(
        ".ranked-choice-poll-option[data-poll-option-id='1f972d1df351de3ce35a787c89faad29'][data-poll-option-rank='1']"
      )
      .exists("the option is ranked first before re-render");

    await render(
      <template><Poll @post={{this.post}} @poll={{this.poll}} /></template>
    );

    assert
      .dom(
        ".ranked-choice-poll-option[data-poll-option-id='1f972d1df351de3ce35a787c89faad29'][data-poll-option-rank='1']"
      )
      .exists("the ranked-choice selection survives the re-render");
  });

  test("keeps an uncommitted selection across a server poll refresh and re-render", async function (assert) {
    this.setProperties({
      post: EmberObject.create({
        id: 42,
        topic: {
          archived: false,
        },
        user_id: 29,
      }),
      poll: trackedObject({
        name: "poll",
        type: "multiple",
        status: "open",
        results: "always",
        min: 1,
        max: 2,
        options: [
          { id: "1f972d1df351de3ce35a787c89faad29", html: "yes", votes: 0 },
          { id: "d7ebc3a9beea2e680815a1e4f57d6db6", html: "no", votes: 0 },
        ],
        voters: 0,
        chart_type: "bar",
      }),
    });

    await render(
      <template><Poll @post={{this.post}} @poll={{this.poll}} /></template>
    );

    await click(
      "li[data-poll-option-id='1f972d1df351de3ce35a787c89faad29'] button"
    );

    Object.assign(this.poll, {
      voters: 9,
      options: [
        { id: "1f972d1df351de3ce35a787c89faad29", html: "yes", votes: 4 },
        { id: "d7ebc3a9beea2e680815a1e4f57d6db6", html: "no", votes: 5 },
      ],
    });
    await settled();

    await render(
      <template><Poll @post={{this.post}} @poll={{this.poll}} /></template>
    );

    assert
      .dom(
        "li[data-poll-option-id='1f972d1df351de3ce35a787c89faad29'] .d-icon-far-square-check"
      )
      .exists(
        "the uncommitted selection survives a server refresh plus re-render"
      );
    assert.strictEqual(
      this.poll.inProgressVote.length,
      1,
      "the persisted in-progress vote is not clobbered by the server merge"
    );
  });

  test("voting on a multiple poll with no min attribute", async function (assert) {
    this.setProperties({
      post: EmberObject.create({
        id: 42,
        topic: {
          archived: false,
        },
        user_id: 29,
      }),
      poll: EmberObject.create({
        name: "poll",
        type: "multiple",
        status: "open",
        results: "always",
        max: 2,
        options: [
          { id: "1f972d1df351de3ce35a787c89faad29", html: "yes", votes: 0 },
          { id: "d7ebc3a9beea2e680815a1e4f57d6db6", html: "no", votes: 0 },
        ],
        voters: 0,
        chart_type: "bar",
      }),
    });
    await render(
      <template><Poll @post={{this.post}} @poll={{this.poll}} /></template>
    );

    assert.dom(".poll-buttons .cast-votes").isDisabled();

    await click(
      "li[data-poll-option-id='1f972d1df351de3ce35a787c89faad29'] button"
    );

    await click(".poll-buttons .cast-votes");
    assert.dom(".chosen").exists();
  });
});
