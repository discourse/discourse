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
  let drafts = [];

  needs.pretender((server, helper) => {
    server.post("/discourse-workflows/trigger-composer-paused", (request) => {
      requests.push(helper.parsePostData(request.requestBody));
      return helper.response(204, "");
    });
    server.post("/drafts.json", (request) => {
      drafts.push(JSON.parse(helper.parsePostData(request.requestBody).data));
      return helper.response({ success: "OK", draft_sequence: 1 });
    });
  });

  needs.hooks.beforeEach(() => {
    requests = [];
    drafts = [];
  });

  function channel() {
    return `/discourse-workflows/composer-message/${loggedInUser().id}`;
  }

  function composerModel(owner) {
    return owner.lookup("service:composer").model;
  }

  function sessionId(owner) {
    return owner
      .lookup("service:workflows-composer-session")
      .idFor(composerModel(owner));
  }

  test("fires the trigger when the user pauses after a phrase", async function (assert) {
    await visit("/");
    await click("#create-topic");
    await fillIn(".d-editor-input", "Meet me at the food stand");
    await triggerKeyEvent(".d-editor-input", "keyup", "Y");

    assert.strictEqual(requests.length, 1);
    assert.strictEqual(
      requests[0].draft_key,
      composerModel(this.owner).draftKey
    );
    assert.strictEqual(requests[0].raw, "Meet me at the food stand");
    assert.strictEqual(requests[0].session_id, sessionId(this.owner));
  });

  test("a reply sends the post it targets, until it replies to the topic instead", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("article#post_3 button.reply");
    await fillIn(".d-editor-input", "Meet me at the food stand");
    await triggerKeyEvent(".d-editor-input", "keyup", "Y");

    assert.strictEqual(requests.length, 1);
    assert.strictEqual(requests[0].reply_to_post_number, "3");

    await click(".composer-actions-trigger");
    await click("[data-action-id='reply_to_topic']");
    await triggerKeyEvent(".d-editor-input", "keyup", "Y");

    assert.strictEqual(requests.length, 2, "the new reply fires again");
    assert.false(
      "reply_to_post_number" in requests[1],
      "the reply to the topic has no target"
    );
  });

  test("autosaves carry the composer session", async function (assert) {
    await visit("/");
    await click("#create-topic");
    await fillIn(".d-editor-input", "Meet me at the food stand");

    assert.strictEqual(
      drafts.at(-1)?.workflowsSessionId,
      sessionId(this.owner)
    );
  });

  test("shows a composer message for the open composer", async function (assert) {
    await visit("/");
    await click("#create-topic");
    const draftKey = composerModel(this.owner).draftKey;

    await publishToMessageBus(channel(), {
      type: "show_composer_message",
      draft_key: "topic_1",
      session_id: sessionId(this.owner),
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
      session_id: "another-composer",
      title: "Not this composer",
      body: "<p>Ignored</p>",
    });
    await settled();
    assert
      .dom(".workflows-composer-message")
      .doesNotExist(
        "ignores messages for another composer with the same draft"
      );

    await publishToMessageBus(channel(), {
      type: "show_composer_message",
      draft_key: draftKey,
      session_id: sessionId(this.owner),
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
    const draftKey = composerModel(this.owner).draftKey;
    const session = sessionId(this.owner);
    await click(".toggle-minimize");

    await publishToMessageBus(channel(), {
      type: "show_composer_message",
      draft_key: draftKey,
      session_id: session,
      title: "Food resources",
      body: "<p>Hello</p>",
    });
    await settled();
    await click("#reply-control");

    assert.dom(".workflows-composer-message").doesNotExist();
  });
});
