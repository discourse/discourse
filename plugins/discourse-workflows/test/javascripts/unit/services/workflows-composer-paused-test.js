import { settled } from "@ember/test-helpers";
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
          return response(this.statuses.shift() ?? 204, "");
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

      this.fired = () =>
        this.requests.map((request) => `${request.workflow_id}:${request.raw}`);
    });

    test("each phrase fires once per draft", async function (assert) {
      this.setTriggers([
        trigger({
          patterns: [pattern("Magic words"), pattern("food stand")],
        }),
      ]);
      const composer = this.openDraft({ title: "Lunch review" });

      await this.pause(composer, "Some MAGIC WORDS");
      assert.deepEqual(this.fired(), ["1:Some MAGIC WORDS"], "ignores case");
      assert.propContains(
        this.requests[0],
        {
          workflow_id: "1",
          trigger_node_id: "trigger-1",
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

    test("a phrase fires again only when the request failed", async function (assert) {
      this.setTriggers([
        trigger({
          patterns: [pattern("Magic words"), pattern("food stand")],
        }),
      ]);
      const composer = this.openDraft();

      this.statuses = [500];
      await this.pause(composer, "Magic words");
      await this.pause(composer, "Magic words!");
      assert.strictEqual(this.requests.length, 2, "retries after an error");

      this.statuses = [422];
      await this.pause(composer, "Magic words! food stand");
      await this.pause(composer, "Magic words! food stand!");
      assert.strictEqual(
        this.requests.length,
        3,
        "doesn't retry what the server declined"
      );
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
        trigger({ workflow_id: 2, category_ids: [2] }),
        trigger({
          workflow_id: 3,
          category_ids: [2],
          include_subcategories: false,
        }),
      ]);

      await this.pause(this.openDraft({ categoryId: 26 }), "In a subcategory");
      assert.deepEqual(this.fired(), ["2:In a subcategory"]);

      await this.pause(this.openDraft({ categoryId: 2 }), "In the parent");
      assert.deepEqual(this.fired(), [
        "2:In a subcategory",
        "2:In the parent",
        "3:In the parent",
      ]);
    });

    test("phrases the browser can't compile are skipped", async function (assert) {
      this.setTriggers([trigger({ patterns: ["(?<name>bad"] })]);

      await this.pause(this.openDraft(), "bad");
      assert.strictEqual(this.requests.length, 0);
    });
  }
);
