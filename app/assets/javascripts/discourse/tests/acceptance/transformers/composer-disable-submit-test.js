import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("composer-disable-submit transformer", function (needs) {
  needs.user();
  needs.settings({
    allow_uncategorized_topics: true,
  });

  test("applying a value transformation - disabled submit", async function (assert) {
    withPluginApi("1.34.0", (api) => {
      api.registerValueTransformer("composer-disable-submit", () => {
        return true;
      });
    });
    await visit("/new-topic?title=topic%20title");
    await click(".submit-panel .create");
    assert
      .dom(".d-editor-textarea-wrapper .popup-tip.bad")
      .isNotVisible(
        "does not show the missing body error because submit disabled"
      );
  });

  test("applying a value transformation - enabled submit", async function (assert) {
    withPluginApi("1.34.0", (api) => {
      api.registerValueTransformer("composer-disable-submit", ({ value }) => {
        return value;
      });
    });

    await visit("/new-topic?title=topic%20title");
    await click(".submit-panel .create");
    assert
      .dom(".d-editor-textarea-wrapper .popup-tip.bad")
      .exists("shows the missing body error because submit enabled");
  });
});
