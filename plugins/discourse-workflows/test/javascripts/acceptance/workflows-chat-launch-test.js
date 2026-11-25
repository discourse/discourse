import {
  click,
  currentRouteName,
  currentURL,
  visit,
} from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import DiscourseURL from "discourse/lib/url";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

const LAUNCH_URL = "/workflows/chat/7/trigger-1";
const CHAT_URL = "/chat/c/help-desk/75";

acceptance("Discourse Workflows | Chat launch", function (needs) {
  needs.user();

  let launches;
  let routeTo;

  needs.hooks.beforeEach(function () {
    launches = [];
    routeTo = sinon.stub(DiscourseURL, "routeTo");
  });

  function stubLaunch(status = 201) {
    pretender.post("/workflows/chat-conversations.json", (request) => {
      launches.push(
        Object.fromEntries(new URLSearchParams(request.requestBody))
      );

      return status === 201
        ? response(201, { url: CHAT_URL })
        : response(status, { errors: ["nope"] });
    });
  }

  test("shows a button and starts nothing until it is clicked", async function (assert) {
    stubLaunch();

    await visit(LAUNCH_URL);

    assert.strictEqual(currentURL(), LAUNCH_URL, "stays on the launch page");
    assert
      .dom(".workflows-chat-launch .btn-primary")
      .hasText(i18n("discourse_workflows.chat_conversation.start"));
    assert.deepEqual(launches, [], "nothing was posted by the page load");

    await click(".workflows-chat-launch .btn-primary");

    assert.deepEqual(
      launches,
      [{ workflow_id: "7", node_id: "trigger-1", draft: "false" }],
      "posts the workflow and node of the launch URL once"
    );
    assert.true(
      routeTo.calledOnceWithExactly(CHAT_URL, { replaceURL: true }),
      "goes to the new chat"
    );
  });

  test("starts a draft chat right away", async function (assert) {
    stubLaunch();

    await visit(`${LAUNCH_URL}?draft=true`);

    assert.deepEqual(
      launches,
      [{ workflow_id: "7", node_id: "trigger-1", draft: "true" }],
      "posts the draft flag"
    );
    assert.true(
      routeTo.calledOnceWithExactly(CHAT_URL, { replaceURL: true }),
      "goes to the new chat"
    );
  });

  [403, 404].forEach((status) => {
    test(`a ${status} from the button reports the error and stays on the page`, async function (assert) {
      stubLaunch(status);

      await visit(LAUNCH_URL);
      await click(".workflows-chat-launch .btn-primary");

      assert.dom(".dialog-body").exists("shows the error");
      assert.strictEqual(currentURL(), LAUNCH_URL);
      assert.true(routeTo.notCalled, "goes nowhere");
      assert
        .dom(".workflows-chat-launch .btn-primary")
        .isNotDisabled("lets the member try again");
    });
  });

  test("a refused draft shows the not found page", async function (assert) {
    stubLaunch(404);

    await visit(`${LAUNCH_URL}?draft=true`);

    assert.strictEqual(currentRouteName(), "exception-unknown");
  });
});
