import selectKit from "discourse/tests/helpers/select-kit-helper";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";
import { withPluginApi } from "discourse/lib/plugin-api";

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
          icon: "cog",
          action() {
            assert.step(`action called`);
            done();
          },
          dropdown: true,
        });
      });

      await visit("/t/internationalization-localization/280");
      const subject = selectKit(".topic-footer-mobile-dropdown");
      await subject.expand();
      await subject.selectRowByValue("foo");

      assert.verifySteps(["action called"]);
    });
  }
);
