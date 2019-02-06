import { acceptance } from "helpers/qunit-helpers";

acceptance("Keyboard Shortcuts", { loggedIn: true });

test("go to first suggested topic", async assert => {
  /* global server */
  server.get("/t/27331/4.json", () => [
    200,
    { "Content-Type": "application/json" },
    {}
  ]);

  server.get("/t/27331.json", () => [
    200,
    { "Content-Type": "application/json" },
    {}
  ]);

  /*
   * No suggested topics exist.
   */

  server.get("/t/9/last.json", () => [
    200,
    { "Content-Type": "application/json" },
    {}
  ]);

  await visit("/t/this-is-a-test-topic/9");
  await keyEvent(document, "keypress", "g".charCodeAt(0));
  await keyEvent(document, "keypress", "s".charCodeAt(0));
  assert.equal(currentURL(), "/t/this-is-a-test-topic/9");

  /*
   * Suggested topics elements exist.
   */

  await visit("/t/internationalization-localization/280");
  await keyEvent(document, "keypress", "g".charCodeAt(0));
  await keyEvent(document, "keypress", "s".charCodeAt(0));
  assert.equal(currentURL(), "/t/polls-are-still-very-buggy/27331/4");

  /*
   * Suggested topic is returned by server.
   */

  server.get("/t/28830/last.json", () => [
    200,
    { "Content-Type": "application/json" },
    {
      suggested_topics: [
        {
          id: 27331,
          slug: "keyboard-shortcuts-are-awesome"
        }
      ]
    }
  ]);

  await visit("/t/1-3-0beta9-no-rate-limit-popups/28830");
  await keyEvent(document, "keypress", "g".charCodeAt(0));
  await keyEvent(document, "keypress", "s".charCodeAt(0));
  assert.equal(currentURL(), "/t/keyboard-shortcuts-are-awesome/27331");
});
