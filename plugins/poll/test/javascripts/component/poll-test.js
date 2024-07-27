import EmberObject from "@ember/object";
import { click, render } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { count, queryAll } from "discourse/tests/helpers/qunit-helpers";

module("Poll | Component | poll", function (hooks) {
  setupRenderingTest(hooks);

  test("no vote", async function (assert) {
    this.setProperties({
      attributes: EmberObject.create({
        post: EmberObject.create({
          id: 42,
          topic: {
            archived: false,
          },
          user_id: 29,
        }),
        poll: EmberObject.create({
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
        vote: [],
        groupableUserFields: [],
      }),
      preloadedVoters: [],
      options: [
        { id: "1f972d1df351de3ce35a787c89faad29", html: "yes", votes: 0 },
        { id: "d7ebc3a9beea2e680815a1e4f57d6db6", html: "no", votes: 0 },
      ],
      id: 42,
      poll: EmberObject.create({
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
      titleHTML: "poll",
      isRankedChoice: false,
      isMultiple: false,
      isNumber: false,
      status: "open",
      closed: false,
      topicArchived: false,
      staffOnly: false,
      voters: 0,
      vote: [],
      rankedChoiceDropdownContent: [],
      hasSavedVote: false,
      rankedChoiceOutcome: {},
      groupableUserFields: [],
      removeVote: () => {},
      castVotes: () => {},
      toggleStatus: () => {},
      toggleResults: () => {},
      toggleOption: () => {},
      fetchVoters: () => {},
    });

    await render(
      hbs`<Poll
        @attrs={{this.attributes}}
        @preloadedVoters={{this.preloadedVoters}}
        @options={{this.options}}
        @id={{this.id}}
        @poll={{this.poll}}
        @post={{this.post}}
        @titleHTML={{this.titleHTML}}
        @isRankedChoice={{this.isRankedChoice}}
        @isMultiple={{this.isMultiple}}
        @isNumber={{this.isNumber}}
        @status={{this.status}}
        @closed={{this.closed}}
        @topicArchived={{this.topicArchived}}
        @staffOnly={{this.staffOnly}}
        @preloadedVoters={{this.preloadedVoters}}
        @voters={{this.voters}}
        @vote={{this.vote}}
        @rankedChoiceDropdownContent={{this.rankedChoiceDropdownContent}}
        @hasSavedVote={{this.hasSavedVote}}
        @rankedChoiceOutcome={{this.rankedChoiceOutcome}}
        @groupableUserFields={{this.groupableUserFields}}
        @removeVote={{this.removeVote}}
        @castVotes={{this.castVotes}}
        @toggleStatus={{this.toggleStatus}}
        @toggleResults={{this.toggleResults}}
        @toggleOption={{this.toggleOption}}
        @fetchVoters={{this.fetchVoters}}
      />`
    );

    assert.strictEqual(count(".chosen"), 0);

    assert.strictEqual(count(".toggle-results"), 0);
  });

  test("one vote", async function (assert) {
    this.setProperties({
      attributes: EmberObject.create({
        post: EmberObject.create({
          id: 42,
          topic: {
            archived: false,
          },
          user_id: 29,
        }),
        poll: EmberObject.create({
          name: "poll",
          type: "regular",
          status: "open",
          results: "always",
          options: [
            { id: "1f972d1df351de3ce35a787c89faad29", html: "yes", votes: 0 },
            { id: "d7ebc3a9beea2e680815a1e4f57d6db6", html: "no", votes: 0 },
          ],
          voters: 1,
          chart_type: "bar",
        }),
        vote: [],
        groupableUserFields: [],
      }),
      preloadedVoters: [],
      options: [
        { id: "1f972d1df351de3ce35a787c89faad29", html: "yes", votes: 1 },
        { id: "d7ebc3a9beea2e680815a1e4f57d6db6", html: "no", votes: 0 },
      ],
      id: 42,
      poll: EmberObject.create({
        name: "poll",
        type: "regular",
        status: "open",
        results: "always",
        options: [
          { id: "1f972d1df351de3ce35a787c89faad29", html: "yes", votes: 1 },
          { id: "d7ebc3a9beea2e680815a1e4f57d6db6", html: "no", votes: 0 },
        ],
        voters: 1,
        chart_type: "bar",
      }),
      titleHTML: "poll",
      isRankedChoice: false,
      isMultiple: false,
      isNumber: false,
      status: "open",
      closed: false,
      topicArchived: false,
      staffOnly: false,
      voters: 1,
      vote: [],
      rankedChoiceDropdownContent: [],
      hasSavedVote: false,
      rankedChoiceOutcome: {},
      groupableUserFields: [],
      removeVote: () => {},
      castVotes: () => {},
      toggleStatus: () => {},
      toggleResults: () => {},
      toggleOption: () => {},
      fetchVoters: () => {},
    });

    await render(
      hbs`<Poll
        @attrs={{this.attributes}}
        @preloadedVoters={{this.preloadedVoters}}
        @options={{this.options}}
        @id={{this.id}}
        @poll={{this.poll}}
        @post={{this.post}}
        @titleHTML={{this.titleHTML}}
        @isRankedChoice={{this.isRankedChoice}}
        @isMultiple={{this.isMultiple}}
        @isNumber={{this.isNumber}}
        @status={{this.status}}
        @closed={{this.closed}}
        @topicArchived={{this.topicArchived}}
        @staffOnly={{this.staffOnly}}
        @preloadedVoters={{this.preloadedVoters}}
        @voters={{this.voters}}
        @vote={{this.vote}}
        @rankedChoiceDropdownContent={{this.rankedChoiceDropdownContent}}
        @hasSavedVote={{this.hasSavedVote}}
        @rankedChoiceOutcome={{this.rankedChoiceOutcome}}
        @groupableUserFields={{this.groupableUserFields}}
        @removeVote={{this.removeVote}}
        @castVotes={{this.castVotes}}
        @toggleStatus={{this.toggleStatus}}
        @toggleResults={{this.toggleResults}}
        @toggleOption={{this.toggleOption}}
        @fetchVoters={{this.fetchVoters}}
      />`
    );

    assert.strictEqual(count(".chosen"), 0);

    assert.strictEqual(count(".toggle-results"), 1);
  });

  test("one vote and its for current user", async function (assert) {
    this.setProperties({
      attributes: EmberObject.create({
        post: EmberObject.create({
          id: 42,
          topic: {
            archived: false,
          },
          user_id: 29,
        }),
        poll: EmberObject.create({
          name: "poll",
          type: "regular",
          status: "open",
          results: "always",
          options: [
            { id: "1f972d1df351de3ce35a787c89faad29", html: "yes", votes: 1 },
            { id: "d7ebc3a9beea2e680815a1e4f57d6db6", html: "no", votes: 0 },
          ],
          voters: 1,
          chart_type: "bar",
        }),
        vote: ["1f972d1df351de3ce35a787c89faad29"],
        groupableUserFields: [],
      }),
      preloadedVoters: [],
      options: [
        { id: "1f972d1df351de3ce35a787c89faad29", html: "yes", votes: 1 },
        { id: "d7ebc3a9beea2e680815a1e4f57d6db6", html: "no", votes: 0 },
      ],
      id: 42,
      poll: EmberObject.create({
        name: "poll",
        type: "regular",
        status: "open",
        results: "always",
        options: [
          { id: "1f972d1df351de3ce35a787c89faad29", html: "yes", votes: 1 },
          { id: "d7ebc3a9beea2e680815a1e4f57d6db6", html: "no", votes: 0 },
        ],
        voters: 1,
        chart_type: "bar",
      }),
      titleHTML: "poll",
      isRankedChoice: false,
      isMultiple: false,
      isNumber: false,
      status: "open",
      closed: false,
      topicArchived: false,
      staffOnly: false,
      voters: 1,
      vote: ["1f972d1df351de3ce35a787c89faad29"],
      rankedChoiceDropdownContent: [],
      hasSavedVote: true,
      rankedChoiceOutcome: {},
      groupableUserFields: [],
      removeVote: () => {},
      castVotes: () => {},
      toggleStatus: () => {},
      toggleResults: () => {},
      toggleOption: () => {},
      fetchVoters: () => {},
    });

    await render(
      hbs`<Poll
        @attrs={{this.attributes}}
        @preloadedVoters={{this.preloadedVoters}}
        @options={{this.options}}
        @id={{this.id}}
        @poll={{this.poll}}
        @post={{this.post}}
        @titleHTML={{this.titleHTML}}
        @isRankedChoice={{this.isRankedChoice}}
        @isMultiple={{this.isMultiple}}
        @isNumber={{this.isNumber}}
        @status={{this.status}}
        @closed={{this.closed}}
        @topicArchived={{this.topicArchived}}
        @staffOnly={{this.staffOnly}}
        @preloadedVoters={{this.preloadedVoters}}
        @voters={{this.voters}}
        @vote={{this.vote}}
        @rankedChoiceDropdownContent={{this.rankedChoiceDropdownContent}}
        @hasSavedVote={{this.hasSavedVote}}
        @rankedChoiceOutcome={{this.rankedChoiceOutcome}}
        @groupableUserFields={{this.groupableUserFields}}
        @removeVote={{this.removeVote}}
        @castVotes={{this.castVotes}}
        @toggleStatus={{this.toggleStatus}}
        @toggleResults={{this.toggleResults}}
        @toggleOption={{this.toggleOption}}
        @fetchVoters={{this.fetchVoters}}
      />`
    );

    assert.strictEqual(count(".chosen"), 1);

    assert.strictEqual(count(".toggle-results"), 1);

    assert.deepEqual(
      Array.from(queryAll(".chosen span")).map((span) => span.innerText),
      ["100%", "yes"]
    );

    await click(".toggle-results");
    assert.strictEqual(
      count("li[data-poll-option-id='1f972d1df351de3ce35a787c89faad29']"),
      1
    );
  });
});
