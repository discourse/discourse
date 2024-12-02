import { currentURL, visit, waitFor } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

acceptance("New Topic - Anonymous", function () {
  test("accessing new-topic route when logged out", async function (assert) {
    await visit("/new-topic?title=topic%20title&body=topic%20body");

    assert.dom(".modal.login-modal").exists("shows the login modal");
  });
});

acceptance("New Topic - Authenticated", function (needs) {
  needs.user();

  test("accessing new-topic route", async function (assert) {
    await visit("/c/1");

    try {
      await visit("/new-topic");
    } catch (error) {
      assert.strictEqual(
        error.message,
        "TransitionAborted",
        "it aborts the transition"
      );
    }

    assert.strictEqual(currentURL(), "/c/1");

    await waitFor(".composer-fields", { timeout: 5000 });

    assert.dom(".composer-fields").exists("it opens the composer");
  });

  test("accessing new-topic route with title, body and category param", async function (assert) {
    await visit(
      "/new-topic?title=topic%20title&body=topic%20body&category=bug"
    );

    assert.dom(".composer-fields").exists("opens composer");

    assert
      .dom("#reply-title")
      .hasValue("topic title", "it pre-fills the topic title");

    assert
      .dom(".d-editor-input")
      .hasValue("topic body", "it pre-fills topic body");

    assert.strictEqual(
      selectKit(".category-chooser").header().value(),
      "1",
      "it selects desired category"
    );

    assert.strictEqual(currentURL(), "/c/1");
  });
});
