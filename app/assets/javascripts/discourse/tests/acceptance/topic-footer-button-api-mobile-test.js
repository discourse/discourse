import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance(
  "Topic - Plugin API - registerTopicFooterButton (mobile)",
  function (needs) {
    needs.user();

    needs.mobileView();

    test("adds topic footer button as a dropdown through API", async function (assert) {
      const done = assert.async();
      withPluginApi("0.13.1", (api) => {
        api.registerTopicFooterButton({
          id: "foo",
          icon: "gear",
          action() {
            assert.step(`action called`);
            done();
          },
          dropdown: true,
        });
      });

      await visit("/t/internationalization-localization/280");
      await click(".topic-footer-mobile-dropdown-trigger");
      await click("#topic-footer-button-foo");

      assert.verifySteps(["action called"]);
    });
  }
);
