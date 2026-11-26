import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("composer-minimum-title-length transformer", function (needs) {
  needs.user();
  needs.settings({
    allow_uncategorized_topics: true,
    min_topic_title_length: 15,
  });

  test("the default value comes from the site settings", async function (assert) {
    await visit("/new-topic?title=Contact");
    await fillIn(".d-editor-input", "a body that is long enough to post");
    await click(".submit-panel .create");

    assert
      .dom(".title-input .popup-tip.bad")
      .includesText("15", "the title is too short");
  });

  test("a lower value lets a shorter title through", async function (assert) {
    withPluginApi((api) => {
      api.registerValueTransformer("composer-minimum-title-length", () => 1);
    });

    await visit("/new-topic?title=Contact");
    await fillIn(".d-editor-input", "a body that is long enough to post");
    await click(".submit-panel .create");

    assert
      .dom(".d-editor-input")
      .doesNotExist("closes the composer on successful creation");
  });
});
