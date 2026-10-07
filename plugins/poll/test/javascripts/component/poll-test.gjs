import EmberObject from "@ember/object";
import { trackedObject } from "@ember/reactive/collections";
import { click, render, settled, waitUntil } from "@ember/test-helpers";
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
      <template><Poll @poll={{this.poll}} @post={{this.post}} /></template>
    );

    assert
      .dom(".poll-voted-choices__choice")
      .exists({ count: 3 }, "the saved ranked choices are shown");

    await click(".poll-buttons .amend-vote");

    assert.dom(".poll-buttons .cast-votes").exists();
    assert
      .dom(".poll-buttons .cast-votes")
      .hasText(
        i18n("poll.cast-votes.update_label"),
        "the cast button offers to update the existing vote"
      );
    assert
      .dom(".poll-buttons .cast-votes")
      .isDisabled("an unchanged selection cannot be re-cast");

    await click(
      ".ranked-choice-poll-option[data-poll-option-id='1f972d1df351de3ce35a787c89faad29'] button"
    );
    await click(".dropdown-menu__item:nth-child(3) button");
    await click(
      ".ranked-choice-poll-option[data-poll-option-id='d7ebc3a9beea2e680815a1e4f57d6db6'] button"
    );
    await click(".dropdown-menu__item:nth-child(2) button");

    assert
      .dom(".poll-buttons .cast-votes")
      .isEnabled("a changed valid selection can be cast");
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
      <template><Poll @poll={{this.poll}} @post={{this.post}} /></template>
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
      <template><Poll @poll={{this.poll}} @post={{this.post}} /></template>
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
      <template><Poll @poll={{this.poll}} @post={{this.post}} /></template>
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
      <template><Poll @poll={{this.poll}} @post={{this.post}} /></template>
    );

    assert
      .dom("table.poll-results-ranked-choice")
      .doesNotExist("the empty outcome table is not rendered");
    assert
      .dom(".results-staff-only")
      .exists("the staff-only results notice is shown instead");
    assert
      .dom(".poll-voted-choices__choice")
      .exists({ count: 2 }, "the voter sees their recorded choices");

    await click(".poll-buttons .amend-vote");

    assert
      .dom(".ranked-choice-poll-option")
      .exists("the ballot options are shown when changing the vote");
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
      <template><Poll @poll={{this.poll}} @post={{this.post}} /></template>
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
      <template><Poll @poll={{this.poll}} @post={{this.post}} /></template>
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
      <template><Poll @poll={{this.poll}} @post={{this.post}} /></template>
    );

    assert.dom("ul.results").exists("results are shown for the saved vote");
    assert.dom(".poll-buttons .cast-votes").doesNotExist();

    await click(".poll-buttons .toggle-results");

    assert
      .dom("ul.options")
      .exists("clicking the button shows the voting view");
    assert.dom(".poll-buttons .cast-votes").exists();

    await render(
      <template><Poll @poll={{this.poll}} @post={{this.post}} /></template>
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
      <template><Poll @poll={{this.poll}} @post={{this.post}} /></template>
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
      <template><Poll @poll={{this.poll}} @post={{this.post}} /></template>
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
      <template><Poll @poll={{this.poll}} @post={{this.post}} /></template>
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
      <template><Poll @poll={{this.poll}} @post={{this.post}} /></template>
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
      <template><Poll @poll={{this.poll}} @post={{this.post}} /></template>
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
      <template><Poll @poll={{this.poll}} @post={{this.post}} /></template>
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
      <template><Poll @poll={{this.poll}} @post={{this.post}} /></template>
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
      <template><Poll @poll={{this.poll}} @post={{this.post}} /></template>
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
      <template><Poll @poll={{this.poll}} @post={{this.post}} /></template>
    );

    assert.dom(".poll-buttons .cast-votes").isDisabled();

    await click(
      "li[data-poll-option-id='1f972d1df351de3ce35a787c89faad29'] button"
    );

    await click(".poll-buttons .cast-votes");
    assert.dom(".chosen").exists();
  });

  const YES = "1f972d1df351de3ce35a787c89faad29";
  const NO = "d7ebc3a9beea2e680815a1e4f57d6db6";
  const optionButton = (id) => `li[data-poll-option-id='${id}'] button`;
  const optionCheckedIcon = (id) =>
    `li[data-poll-option-id='${id}'] .d-icon-far-square-check`;

  function hiddenResultsPoll(overrides = {}) {
    return trackedObject({
      name: "poll",
      type: "multiple",
      status: "open",
      results: "on_close",
      min: 1,
      max: 2,
      options: [
        { id: YES, html: "yes" },
        { id: NO, html: "no" },
      ],
      voters: 0,
      chart_type: "bar",
      ...overrides,
    });
  }

  function hiddenResultsPost(votes) {
    return EmberObject.create({
      id: 42,
      topic: { archived: false },
      user_id: 29,
      ...(votes ? { polls_votes: { poll: votes } } : {}),
    });
  }

  function stubHiddenResultsVote(overrides = {}) {
    pretender.put("/polls/vote", () =>
      response({ poll: hiddenResultsPoll({ voters: 1, ...overrides }) })
    );
  }

  async function renderHiddenResultsPoll(ctx, { votes, ...overrides } = {}) {
    ctx.setProperties({
      post: hiddenResultsPost(votes),
      poll: hiddenResultsPoll(overrides),
    });

    await render(
      <template><Poll @poll={{ctx.poll}} @post={{ctx.post}} /></template>
    );
  }

  test("shows the voted choices instead of the ballot after voting on a hidden-results poll", async function (assert) {
    stubHiddenResultsVote();
    await renderHiddenResultsPoll(this);

    assert.dom("ul.options").exists();
    assert
      .dom(".poll-buttons .cast-votes")
      .hasText(i18n("poll.cast-votes.label"));

    await click(optionButton(YES));
    await click(".poll-buttons .cast-votes");

    assert.dom("ul.options").doesNotExist("the ballot is replaced");
    assert.dom("ul.results").doesNotExist("results stay hidden");
    assert
      .dom(".poll-voted-choices__choice")
      .exists({ count: 1 }, "the recorded choice is shown");
    assert.dom(".poll-voted-choices__choice").hasText("yes");
    assert.dom(".poll-buttons .cast-votes").doesNotExist();
    assert.dom(".poll-buttons .amend-vote").exists();
    assert
      .dom(".poll-buttons .remove-vote")
      .doesNotExist("undo only appears while changing the vote");
    assert
      .dom(".poll-info_instructions .vote-recorded")
      .exists("the info column confirms the recorded vote");
    assert
      .dom(".poll-info_instructions .multiple-help-text")
      .doesNotExist("the confirmation takes the help text's slot");
    assert
      .dom(".results-on-close")
      .exists("the results hint is unchanged by voting");
  });

  test("can change the vote from the voted choices view", async function (assert) {
    stubHiddenResultsVote();
    await renderHiddenResultsPoll(this, { votes: [YES], voters: 1 });

    assert.dom(".poll-voted-choices__choice").exists({ count: 1 });

    await click(".poll-buttons .amend-vote");

    assert.dom("ul.options").exists("the ballot is shown again");
    assert
      .dom(optionCheckedIcon(YES))
      .exists("the saved choice is preselected");
    assert
      .dom(".poll-buttons .cast-votes")
      .hasText(i18n("poll.cast-votes.update_label"));
    assert
      .dom(".poll-buttons .cast-votes")
      .isDisabled("an unchanged selection cannot be re-cast");

    await click(optionButton(NO));

    assert.dom(".poll-buttons .cast-votes").isEnabled();

    await click(".poll-buttons .cast-votes");

    assert
      .dom(".poll-voted-choices__choice")
      .exists({ count: 2 }, "the updated choices are shown");
  });

  test("keeps the current vote when going back from the ballot", async function (assert) {
    await renderHiddenResultsPoll(this, { votes: [YES], voters: 1 });

    requests = 0;

    await click(".poll-buttons .amend-vote");
    await click(optionButton(NO));
    await click(".poll-buttons .keep-vote");

    assert.strictEqual(requests, 0, "no vote is cast");
    assert
      .dom(".poll-voted-choices__choice")
      .exists({ count: 1 }, "the recorded vote is unchanged");

    await click(".poll-buttons .amend-vote");

    assert
      .dom(optionCheckedIcon(NO))
      .doesNotExist("the abandoned selection is discarded");
  });

  test("returns to the ballot after undoing the vote", async function (assert) {
    pretender.delete("/polls/vote", () =>
      response({ poll: hiddenResultsPoll() })
    );

    await renderHiddenResultsPoll(this, { votes: [YES], voters: 1 });

    await click(".poll-buttons .amend-vote");

    assert
      .dom(".poll-buttons .remove-vote")
      .exists("undo is available while changing the vote");

    await click(".poll-buttons .remove-vote");

    assert.dom(".poll-voted-choices__choice").doesNotExist();
    assert.dom("ul.options").exists("the pristine ballot is shown");
    assert
      .dom(".poll-buttons .cast-votes")
      .hasText(i18n("poll.cast-votes.label"));
    assert.dom(".poll-buttons .keep-vote").doesNotExist();
  });

  test("keeps the voted choices view after the poll component is re-rendered", async function (assert) {
    await renderHiddenResultsPoll(this, { votes: [YES], voters: 1 });

    assert.dom(".poll-voted-choices__choice").exists({ count: 1 });

    await render(
      <template><Poll @poll={{this.poll}} @post={{this.post}} /></template>
    );

    assert
      .dom(".poll-voted-choices__choice")
      .exists({ count: 1 }, "the voted choices survive a re-render");

    await click(".poll-buttons .amend-vote");

    await render(
      <template><Poll @poll={{this.poll}} @post={{this.post}} /></template>
    );

    assert
      .dom("ul.options")
      .exists("an in-progress vote change survives a re-render");
  });

  test("shows the voted choices after voting on a staff_only poll as non-staff", async function (assert) {
    stubHiddenResultsVote({ results: "staff_only" });
    await renderHiddenResultsPoll(this, { results: "staff_only" });

    await click(optionButton(YES));
    await click(".poll-buttons .cast-votes");

    assert.dom("ul.results").doesNotExist("results stay hidden");
    assert.dom(".poll-voted-choices__choice").exists({ count: 1 });
    assert.dom(".poll-info_instructions .vote-recorded").exists();
    assert.dom(".results-staff-only").exists();
  });

  test("casts a single vote when the cast button is clicked twice quickly", async function (assert) {
    let voteRequests = 0;
    let resolveVote;
    pretender.put("/polls/vote", () => {
      voteRequests++;
      return new Promise((resolve) => {
        resolveVote = resolve;
      });
    });

    await renderHiddenResultsPoll(this);

    await click(optionButton(YES));

    const castButton = document.querySelector(".poll-buttons .cast-votes");
    castButton.click();
    castButton.click();

    await waitUntil(() => resolveVote);
    resolveVote(response({ poll: hiddenResultsPoll({ voters: 1 }) }));
    await settled();

    assert.strictEqual(voteRequests, 1, "only one vote request is sent");
    assert.dom(".poll-voted-choices__choice").exists({ count: 1 });
  });

  test("moves focus to the change vote button after casting", async function (assert) {
    stubHiddenResultsVote();
    await renderHiddenResultsPoll(this);

    await click(optionButton(YES));
    await click(".poll-buttons .cast-votes");

    assert.dom(".poll-buttons .amend-vote").isFocused();
  });

  test("keeps the vote when re-clicking the current choice while changing a single-choice vote", async function (assert) {
    let deleteRequests = 0;
    pretender.delete("/polls/vote", () => {
      deleteRequests++;
      return response({ poll: hiddenResultsPoll({ type: "regular" }) });
    });

    await renderHiddenResultsPoll(this, {
      votes: [YES],
      type: "regular",
      voters: 1,
    });

    await click(".poll-buttons .amend-vote");
    await click(optionButton(YES));

    assert.strictEqual(deleteRequests, 0, "the vote is not deleted");
    assert
      .dom(".poll-voted-choices__choice")
      .exists({ count: 1 }, "the recorded vote is kept");
  });

  test("shows the results when a hidden-results poll is closed while displayed", async function (assert) {
    await renderHiddenResultsPoll(this, { votes: [YES], voters: 1 });

    assert.dom(".poll-voted-choices__choice").exists({ count: 1 });

    Object.assign(this.poll, {
      status: "closed",
      options: [
        { id: YES, html: "yes", votes: 1 },
        { id: NO, html: "no", votes: 0 },
      ],
    });
    await settled();

    assert
      .dom("ul.results")
      .exists("the summary flips to results once counts arrive");
  });

  test("shows the automatic close countdown only while the poll is open", async function (assert) {
    await renderHiddenResultsPoll(this, { close: "2035-01-01 12:00:00 UTC" });

    assert
      .dom(".poll-info_instructions li .d-icon-far-clock")
      .exists("an open poll with a close date shows the countdown");

    this.poll.status = "closed";
    await settled();

    assert
      .dom(".poll-info_instructions li .d-icon-far-clock")
      .doesNotExist("a manually closed poll does not promise a countdown");
  });

  test("shows the voted choice after voting on a single-choice hidden-results poll", async function (assert) {
    stubHiddenResultsVote({ type: "regular" });
    await renderHiddenResultsPoll(this, {
      type: "regular",
      min: null,
      max: null,
    });

    await click(optionButton(YES));

    assert
      .dom(".poll-voted-choices__choice")
      .exists({ count: 1 }, "the recorded choice replaces the ballot");
    assert.dom(".poll-buttons .amend-vote").exists();
  });
});
