import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { click, render } from "@ember/test-helpers";
import {
  count,
  exists,
  query,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import EmberObject from "@ember/object";
import I18n from "I18n";

let requests = 0;

module("Integration | Component | Widget | discourse-poll", function (hooks) {
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

  const template = hbs`
    <MountWidget
      @widget="discourse-poll"
      @args={{hash
        id=this.id
        post=this.post
        poll=this.poll
        vote=this.vote
        groupableUserFields=this.groupableUserFields
      }}
    />
  `;

  test("can vote", async function (assert) {
    this.setProperties({
      post: EmberObject.create({
        id: 42,
        topic: {
          archived: false,
        },
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
    });

    await render(template);

    requests = 0;

    await click("li[data-poll-option-id='1f972d1df351de3ce35a787c89faad29']");
    assert.strictEqual(requests, 1);
    assert.strictEqual(count(".chosen"), 1);
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

  test("cannot vote if not member of the right group", async function (assert) {
    this.setProperties({
      post: EmberObject.create({
        id: 42,
        topic: {
          archived: false,
        },
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
        groups: "foo",
      }),
      vote: [],
      groupableUserFields: [],
    });

    await render(template);

    requests = 0;

    await click("li[data-poll-option-id='1f972d1df351de3ce35a787c89faad29']");
    assert.strictEqual(
      query(".poll-container .alert").innerText,
      I18n.t("poll.results.groups.title", { groups: "foo" })
    );
    assert.strictEqual(requests, 0);
    assert.ok(!exists(".chosen"));
  });

  test("voting on a multiple poll with no min attribute", async function (assert) {
    this.setProperties({
      post: EmberObject.create({
        id: 42,
        topic: {
          archived: false,
        },
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
      vote: [],
      groupableUserFields: [],
    });

    await render(template);
    assert.ok(exists(".poll-buttons .cast-votes[disabled=true]"));

    await click("li[data-poll-option-id='1f972d1df351de3ce35a787c89faad29']");
    await click(".poll-buttons .cast-votes");
    assert.ok(exists(".chosen"));
  });
});
