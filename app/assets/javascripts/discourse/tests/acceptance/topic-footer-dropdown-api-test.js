import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import selectKit from "discourse/tests/helpers/select-kit-helper";

acceptance(
  "Topic - Plugin API - registerTopicFooterDropdown",
  function (needs) {
    needs.user();

    test("adds topic footer dropdown through API", async function (assert) {
      const done = assert.async();
      withPluginApi("0.13.1", (api) => {
        api.registerTopicFooterDropdown({
          id: "my-button",
          content() {
            return [{ id: 1, name: "foo" }];
          },
          action(itemId) {
            assert.step(`action ${itemId} called`);
            done();
          },
        });
      });

      await visit("/t/internationalization-localization/280");

      const subject = selectKit("#topic-footer-dropdown-my-button");
      await subject.expand();
      await subject.selectRowByValue(1);

      assert.verifySteps(["action 1 called"]);
    });
  }
);
