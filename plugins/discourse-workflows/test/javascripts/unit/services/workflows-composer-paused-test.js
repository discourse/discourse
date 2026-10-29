import { settled, waitUntil } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import Composer, {
  CREATE_TOPIC,
  EDIT,
  PRIVATE_MESSAGE,
  REPLY,
} from "discourse/models/composer";
import pretender, {
  parsePostData,
  response,
} from "discourse/tests/helpers/create-pretender";
import { SESSION_ID_FIELD } from "discourse/plugins/discourse-workflows/discourse/services/workflows-composer-session";

// Same shape as the server's watched word regexps.
const WORD = "[\\p{L}\\p{M}\\p{N}\\p{Pc}]";
const pattern = (phrase) => `(?:(?<!${WORD}))(${phrase})(?:(?!${WORD}))`;

function trigger(attrs = {}) {
  return {
    workflow_id: 1,
    trigger_node_id: "trigger-1",
    patterns: [],
    composer_actions: ["create_topic", "reply"],
    category_ids: [],
    include_subcategories: true,
    ...attrs,
  };
}

module(
  "Discourse Workflows | Unit | Service | composer paused",
  function (hooks) {
    setupTest(hooks);

    hooks.beforeEach(function () {
      this.requests = [];
      this.statuses = [];
      pretender.post(
        "/discourse-workflows/trigger-composer-paused",
        (request) => {
          this.requests.push(parsePostData(request.requestBody));
          const [status, body] = [this.statuses.shift() ?? 204].flat();
          return response(status, body ?? "");
        }
      );

      this.setTriggers = (triggers) => {
        this.owner
          .lookup("service:site")
          .set("composer_paused_workflows", triggers);
        this.service = this.owner.lookup("service:workflows-composer-paused");
      };

      this.openDraft = (attrs = {}) =>
        this.owner.lookup("service:store").createRecord("composer", {
          action: CREATE_TOPIC,
          composeState: Composer.OPEN,
          draftKey: "new_topic",
          disableDrafts: true,
          ...attrs,
        });

      this.pause = async (composer, reply) => {
        composer.set("reply", reply);
        this.service.typingPaused(composer);
        await settled();
      };

      this.sent = () => this.requests.map((request) => request.raw);
    });

    test("each phrase fires once per draft", async function (assert) {
      this.setTriggers([
        trigger({
          patterns: [pattern("Magic words"), pattern("food stand")],
        }),
      ]);
      const composer = this.openDraft({ title: "Lunch review" });

      await this.pause(composer, "Some MAGIC WORDS");
      assert.deepEqual(this.sent(), ["Some MAGIC WORDS"], "ignores case");
      assert.propContains(
        this.requests[0],
        {
          draft_key: "new_topic",
          composer_action: "create_topic",
          title: "Lunch review",
          raw: "Some MAGIC WORDS",
        },
        "sends the draft"
      );

      await this.pause(composer, "Magic words, and more Magic words");
      assert.strictEqual(
        this.requests.length,
        1,
        "a repeated phrase is skipped"
      );

      await this.pause(composer, "Magic words. food stand");
      assert.strictEqual(this.requests.length, 2, "a new phrase fires");

      await this.pause(this.openDraft(), "Magic words");
      assert.strictEqual(this.requests.length, 3, "a new draft starts over");

      assert.strictEqual(
        this.requests[0].session_id,
        this.requests[1].session_id,
        "a draft keeps its session"
      );
      assert.notStrictEqual(
        this.requests[1].session_id,
        this.requests[2].session_id,
        "a new draft gets a new session"
      );
    });

    test("reopening a composer starts a new session", async function (assert) {
      this.setTriggers([trigger({ patterns: [pattern("Magic words")] })]);
      const composer = this.openDraft();

      await this.pause(composer, "Magic words");
      // opening the composer again restores the draft's fields
      composer.set(SESSION_ID_FIELD, "saved-in-the-draft");
      await this.pause(composer, "Magic words!");

      assert.strictEqual(this.requests.length, 2, "the phrase fires again");
      assert.notStrictEqual(
        this.requests[0].session_id,
        this.requests[1].session_id,
        "in a new session"
      );
      assert.strictEqual(
        composer.get(SESSION_ID_FIELD),
        this.requests[1].session_id,
        "which the draft keeps"
      );
    });

    test("a reply sends the post it targets", async function (assert) {
      this.setTriggers([trigger({ patterns: [pattern("Magic words")] })]);
      const topic = { id: 2, category_id: 1 };

      await this.pause(
        this.openDraft({ action: REPLY, topic, post: { post_number: 3 } }),
        "Magic words"
      );
      await this.pause(this.openDraft({ action: REPLY, topic }), "Magic words");

      assert.strictEqual(this.requests[0].reply_to_post_number, "3");
      assert.false(
        "reply_to_post_number" in this.requests[1],
        "a reply to the topic has no target"
      );
    });

    test("a restored reply waits for its target post to load", async function (assert) {
      this.setTriggers([trigger({ patterns: [pattern("Magic words")] })]);
      const composer = this.openDraft({
        action: REPLY,
        topic: { id: 2, category_id: 1 },
        loading: true,
      });

      await this.pause(composer, "Magic words");
      assert.strictEqual(this.requests.length, 0, "skips pauses while loading");

      composer.setProperties({ loading: false, post: { post_number: 3 } });
      await this.pause(composer, "Magic words!");
      assert.strictEqual(this.requests[0].reply_to_post_number, "3");
    });

    test("a pause sends one request for all the triggers it matched", async function (assert) {
      this.setTriggers([
        trigger({ workflow_id: 1, patterns: [pattern("Magic words")] }),
        trigger({ workflow_id: 2, patterns: [pattern("food stand")] }),
        trigger({ workflow_id: 3 }),
      ]);

      await this.pause(this.openDraft(), "Magic words at the food stand");

      assert.deepEqual(this.sent(), ["Magic words at the food stand"]);
    });

    test("pauses during a request are folded into one check of the latest draft", async function (assert) {
      this.setTriggers([
        trigger({
          patterns: [pattern("Magic words"), pattern("food stand")],
        }),
      ]);
      const held = [];
      pretender.post(
        "/discourse-workflows/trigger-composer-paused",
        (request) => {
          this.requests.push(parsePostData(request.requestBody));
          held.push(request);
          return response(204, "");
        },
        true
      );
      const composer = this.openDraft();

      composer.set("reply", "Magic words");
      this.service.typingPaused(composer);
      await waitUntil(() => held.length === 1);

      composer.set("reply", "Magic words. food");
      this.service.typingPaused(composer);
      composer.set("reply", "Magic words. food stand");
      this.service.typingPaused(composer);
      await new Promise((resolve) => setTimeout(resolve, 100));
      assert.strictEqual(this.requests.length, 1, "waits for the request");

      pretender.resolve(held[0]);
      await waitUntil(() => held.length === 2);
      pretender.resolve(held[1]);
      await settled();

      assert.deepEqual(this.sent(), ["Magic words", "Magic words. food stand"]);
    });

    test("a failed request is retried after a wait", async function (assert) {
      const clock = sinon.useFakeTimers({ now: 1000, toFake: ["Date"] });
      this.setTriggers([trigger({ patterns: [pattern("Magic words")] })]);
      const composer = this.openDraft();

      try {
        this.statuses = [500];
        await this.pause(composer, "Magic words");
        await this.pause(composer, "Magic words!");
        assert.strictEqual(this.requests.length, 1, "waits after an error");

        clock.tick(15000);
        this.statuses = [[429, { extras: { wait_seconds: 30 } }]];
        await this.pause(composer, "Magic words!");
        assert.strictEqual(this.requests.length, 2, "then asks again");

        clock.tick(15000);
        await this.pause(composer, "Magic words!");
        assert.strictEqual(
          this.requests.length,
          2,
          "waits as long as the rate limit says"
        );

        clock.tick(15000);
        await this.pause(composer, "Magic words!");
        await this.pause(composer, "Magic words!!");
        assert.strictEqual(
          this.requests.length,
          3,
          "a phrase the server answered for doesn't fire again"
        );
      } finally {
        clock.restore();
      }
    });

    test("the title counts, quotes don't", async function (assert) {
      this.setTriggers([trigger({ patterns: [pattern("Magic words")] })]);

      await this.pause(
        this.openDraft(),
        '[quote="sam, post:1, topic:2"]Magic words[/quote]\n> Magic words\n<!-- Magic words -->'
      );
      assert.strictEqual(this.requests.length, 0, "quoted text is ignored");

      await this.pause(
        this.openDraft(),
        "[quote]a [quote]b[/quote] Magic words[/quote] Hello"
      );
      assert.strictEqual(
        this.requests.length,
        0,
        "bare and nested quotes are ignored"
      );

      await this.pause(this.openDraft({ title: "Magic words" }), "Hello");
      assert.strictEqual(this.requests.length, 1, "the title matches");
    });

    test("triggers without phrases fire on changed text, throttled", async function (assert) {
      const clock = sinon.useFakeTimers({ now: 1000, toFake: ["Date"] });
      this.setTriggers([trigger()]);
      const composer = this.openDraft();

      try {
        await this.pause(composer, "Hello");
        await this.pause(composer, "Hello there");
        assert.strictEqual(this.requests.length, 1, "throttled");

        clock.tick(15000);
        await this.pause(composer, "Hello there");
        assert.strictEqual(this.requests.length, 2, "fires after the interval");

        clock.tick(15000);
        await this.pause(composer, "Hello there");
        assert.strictEqual(
          this.requests.length,
          2,
          "unchanged text is skipped"
        );
      } finally {
        clock.restore();
      }
    });

    test("a trigger without phrases retries the same text after a failed request", async function (assert) {
      const clock = sinon.useFakeTimers({ now: 1000, toFake: ["Date"] });
      this.setTriggers([trigger()]);
      const composer = this.openDraft();

      try {
        this.statuses = [500];
        await this.pause(composer, "Hello");
        clock.tick(15000);
        await this.pause(composer, "Hello");

        assert.deepEqual(this.sent(), ["Hello", "Hello"]);
      } finally {
        clock.restore();
      }
    });

    test("triggers without phrases share one interval", async function (assert) {
      const clock = sinon.useFakeTimers({ now: 1000, toFake: ["Date"] });
      this.setTriggers([
        trigger({ workflow_id: 1 }),
        trigger({
          workflow_id: 2,
          category_ids: [26],
          include_subcategories: false,
        }),
      ]);
      const composer = this.openDraft({ categoryId: 2 });

      try {
        await this.pause(composer, "Hello");
        clock.tick(5000);
        composer.set("categoryId", 26);
        await this.pause(composer, "Hello there");
        assert.strictEqual(
          this.requests.length,
          2,
          "a newly applying trigger fires"
        );

        clock.tick(10000);
        await this.pause(composer, "Hello there again");
        assert.strictEqual(
          this.requests.length,
          2,
          "the first trigger waits with the second"
        );

        clock.tick(5000);
        await this.pause(composer, "Hello there once more");
        assert.strictEqual(
          this.requests.length,
          3,
          "then both fire in one request"
        );
      } finally {
        clock.restore();
      }
    });

    test("only open new topics and replies fire", async function (assert) {
      this.setTriggers([trigger({ patterns: [pattern("Magic words")] })]);

      await this.pause(this.openDraft({ action: EDIT }), "Magic words");
      await this.pause(
        this.openDraft({ action: PRIVATE_MESSAGE }),
        "Magic words"
      );
      await this.pause(
        this.openDraft({
          action: REPLY,
          topic: { id: 2, archetype: "private_message" },
        }),
        "Magic words"
      );
      await this.pause(
        this.openDraft({ composeState: Composer.DRAFT }),
        "Magic words"
      );
      assert.strictEqual(this.requests.length, 0);

      await this.pause(
        this.openDraft({ action: REPLY, topic: { id: 2, category_id: 1 } }),
        "Magic words"
      );
      assert.strictEqual(this.requests[0].composer_action, "reply");
      assert.strictEqual(this.requests[0].topic_id, "2");
    });

    test("composer actions and categories filter triggers", async function (assert) {
      this.setTriggers([
        trigger({ workflow_id: 1, composer_actions: ["reply"] }),
        trigger({
          workflow_id: 2,
          category_ids: [2],
          include_subcategories: false,
        }),
        trigger({
          workflow_id: 3,
          category_ids: [2],
          patterns: [pattern("Magic words")],
        }),
      ]);

      await this.pause(this.openDraft({ categoryId: 26 }), "Hello");
      assert.deepEqual(this.sent(), [], "no trigger applies");

      await this.pause(this.openDraft({ categoryId: 26 }), "Magic words");
      assert.deepEqual(
        this.sent(),
        ["Magic words"],
        "a phrase matches in a subcategory"
      );

      await this.pause(this.openDraft({ categoryId: 2 }), "Hello");
      assert.deepEqual(
        this.sent(),
        ["Magic words", "Hello"],
        "a category without its subcategories matches"
      );
    });

    test("phrases the browser can't compile are skipped", async function (assert) {
      this.setTriggers([trigger({ patterns: ["(?<name>bad"] })]);

      await this.pause(this.openDraft(), "bad");
      assert.strictEqual(this.requests.length, 0);
    });
  }
);
