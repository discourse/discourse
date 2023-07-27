import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import pretender from "discourse/tests/helpers/create-pretender";

acceptance("Page tracking", function () {
  test("sets the discourse-track-view header correctly", async function (assert) {
    const trackViewHeaderName = "Discourse-Track-View";
    assert.strictEqual(
      pretender.handledRequests.length,
      0,
      "no requests logged before app boot"
    );

    await visit("/");
    assert.strictEqual(
      pretender.handledRequests.length,
      1,
      "one request logged during app boot"
    );
    assert.strictEqual(
      pretender.handledRequests[0].requestHeaders[trackViewHeaderName],
      undefined,
      "does not track view for ajax before a transition has taken place"
    );

    await click("#site-logo");
    assert.strictEqual(
      pretender.handledRequests.length,
      2,
      "second request logged during next transition"
    );
    assert.strictEqual(
      pretender.handledRequests[1].requestHeaders[trackViewHeaderName],
      "true",
      "sends track-view header for subsequent requests"
    );
  });
});
