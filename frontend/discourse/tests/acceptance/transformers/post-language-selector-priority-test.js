import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("post-language-selector-priority transformer", function (needs) {
  needs.user();
  needs.settings({
    content_localization_enabled: true,
    available_content_localization_locales: [{ value: "en" }, { value: "fr" }],
    available_locales: [{ name: "English", value: "en" }],
    allow_uncategorized_topics: true,
  });

  function toolbarButtonClasses() {
    return [
      ...document.querySelectorAll(
        ".d-editor-button-bar .toolbar__button, .d-editor-button-bar .toolbar-popup-menu-options"
      ),
    ].map((b) => b.classList);
  }

  function buttonIndex(classes, name) {
    return classes.findIndex((c) => c.contains(name));
  }

  test("language selector is in the first group by default", async function (assert) {
    await visit("/new-topic");

    const buttons = toolbarButtonClasses();
    const languageIdx = buttonIndex(buttons, "post-language-selector-trigger");
    const boldIdx = buttonIndex(buttons, "bold");

    assert.true(
      languageIdx < boldIdx,
      "language selector appears before formatting buttons"
    );
  });

  test("language selector moves to the last group when transformer deprioritizes it", async function (assert) {
    withPluginApi((api) => {
      api.registerValueTransformer(
        "post-language-selector-priority",
        () => "last"
      );
    });

    await visit("/new-topic");

    const buttons = toolbarButtonClasses();
    const languageIdx = buttonIndex(buttons, "post-language-selector-trigger");
    const boldIdx = buttonIndex(buttons, "bold");

    assert.true(
      languageIdx > boldIdx,
      "language selector appears after formatting buttons"
    );
  });
});
