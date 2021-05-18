import { currentURL, triggerKeyEvent, visit } from "@ember/test-helpers";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";

acceptance("Keyboard Shortcuts", function (needs) {
  needs.pretender((server, helper) => {
    server.get("/t/27331/4.json", () => helper.response({}));
    server.get("/t/27331.json", () => helper.response({}));

    // No suggested topics exist.
    server.get("/t/9/last.json", () => helper.response({}));

    // Suggested topic is returned by server.
    server.get("/t/28830/last.json", () => {
      return helper.response({
        suggested_topics: [
          {
            id: 27331,
            slug: "keyboard-shortcuts-are-awesome",
          },
        ],
      });
    });
  });

  test("go to first suggested topic", async function (assert) {
    await visit("/t/this-is-a-test-topic/9");
    await triggerKeyEvent(document, "keypress", "g".charCodeAt(0));
    await triggerKeyEvent(document, "keypress", "s".charCodeAt(0));
    assert.equal(currentURL(), "/t/this-is-a-test-topic/9");

    // Suggested topics elements exist.
    await visit("/t/internationalization-localization/280");
    await triggerKeyEvent(document, "keypress", "g".charCodeAt(0));
    await triggerKeyEvent(document, "keypress", "s".charCodeAt(0));
    assert.equal(currentURL(), "/t/polls-are-still-very-buggy/27331/4");

    await visit("/t/1-3-0beta9-no-rate-limit-popups/28830");
    await triggerKeyEvent(document, "keypress", "g".charCodeAt(0));
    await triggerKeyEvent(document, "keypress", "s".charCodeAt(0));
    assert.equal(currentURL(), "/t/keyboard-shortcuts-are-awesome/27331");
  });
});
