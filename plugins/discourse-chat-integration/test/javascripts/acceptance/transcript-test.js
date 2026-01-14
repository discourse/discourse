import { settled, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

/**
 * Workaround for https://github.com/tildeio/router.js/pull/335
 */
async function visitWithRedirects(url) {
  try {
    await visit(url);
  } catch (error) {
    const { message } = error;
    if (message !== "TransitionAborted") {
      throw error;
    }
    await settled();
  }
}

acceptance("Chat Integration - slack transcript", function (needs) {
  needs.user({
    can_create_topic: true,
  });

  needs.pretender((server, helper) => {
    server.get("/chat-transcript/abcde", () => {
      return helper.response({
        content: "This is a chat transcript",
      });
    });
  });

  test("Can open composer with transcript", async function (assert) {
    await visitWithRedirects("/chat-transcript/abcde");
    assert.dom(".d-editor-input").hasValue("This is a chat transcript");
  });
});
