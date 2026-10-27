import {
  click,
  fillIn,
  settled,
  triggerKeyEvent,
  visit,
} from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  loggedInUser,
  publishToMessageBus,
} from "discourse/tests/helpers/qunit-helpers";

const WORD = "[\\p{L}\\p{M}\\p{N}\\p{Pc}]";

acceptance("Discourse Workflows | Composer paused", function (needs) {
  needs.user({ discourse_workflows_composer_message_last_id: 0 });
  needs.settings({ allow_uncategorized_topics: true });
  needs.site({
    composer_paused_workflows: [
      {
        workflow_id: 1,
        trigger_node_id: "trigger-1",
        patterns: [`(?:(?<!${WORD}))(food stand)(?:(?!${WORD}))`],
        composer_actions: ["create_topic", "reply"],
        category_ids: [],
        include_subcategories: true,
      },
    ],
  });

  let requests = [];

  needs.pretender((server, helper) => {
    server.post("/discourse-workflows/trigger-composer-paused", (request) => {
      requests.push(helper.parsePostData(request.requestBody));
      return helper.response(204, "");
    });
  });

  needs.hooks.beforeEach(() => {
    requests = [];
  });

  function channel() {
    return `/discourse-workflows/composer-message/${loggedInUser().id}`;
  }

  test("fires the trigger when the user pauses after a phrase", async function (assert) {
    await visit("/");
    await click("#create-topic");
    await fillIn(".d-editor-input", "Meet me at the food stand");
    await triggerKeyEvent(".d-editor-input", "keyup", "Y");

    assert.strictEqual(requests.length, 1);
    assert.strictEqual(
      requests[0].draft_key,
      this.owner.lookup("service:composer").model.draftKey
    );
    assert.strictEqual(requests[0].raw, "Meet me at the food stand");
  });

  test("shows a composer message for the open draft", async function (assert) {
    await visit("/");
    await click("#create-topic");
    const draftKey = this.owner.lookup("service:composer").model.draftKey;

    await publishToMessageBus(channel(), {
      type: "show_composer_message",
      draft_key: "topic_1",
      title: "Not this draft",
      body: "<p>Ignored</p>",
    });
    await settled();
    assert
      .dom(".workflows-composer-message")
      .doesNotExist("ignores messages for another draft");

    await publishToMessageBus(channel(), {
      type: "show_composer_message",
      draft_key: draftKey,
      title: "Food resources",
      body: "<p>Our community can <a href='/categories'>help</a>.</p>",
    });
    await settled();

    assert
      .dom(".workflows-composer-message h3")
      .hasText("Food resources", "shows the title");
    assert
      .dom(".workflows-composer-message a[href='/categories']")
      .hasText("help", "renders the cooked body");
  });

  test("doesn't show a composer message once the composer is minimized", async function (assert) {
    await visit("/");
    await click("#create-topic");
    const draftKey = this.owner.lookup("service:composer").model.draftKey;
    await click(".toggle-minimize");

    await publishToMessageBus(channel(), {
      type: "show_composer_message",
      draft_key: draftKey,
      title: "Food resources",
      body: "<p>Hello</p>",
    });
    await settled();
    await click("#reply-control");

    assert.dom(".workflows-composer-message").doesNotExist();
  });
});
