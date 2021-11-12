import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";

acceptance("Topic - Plugin API - registerTopicFooterButton", function (needs) {
  needs.user();

  test("adds topic footer button through API", async function (assert) {
    const done = assert.async();
    withPluginApi("0.13.1", (api) => {
      api.registerTopicFooterButton({
        id: "my-button",
        icon: "cog",
        action() {
          assert.step("action called");
          done();
        },
      });
    });

    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-button-my-button");

    assert.verifySteps(["action called"]);
  });
});
