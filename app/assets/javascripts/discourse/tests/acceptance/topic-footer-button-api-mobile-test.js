import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

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
      const subject = selectKit(".topic-footer-mobile-dropdown");
      await subject.expand();
      await subject.selectRowByValue("foo");

      assert.verifySteps(["action called"]);
    });
  }
);
