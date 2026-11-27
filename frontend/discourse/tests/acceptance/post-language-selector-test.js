import {
  click,
  find,
  findAll,
  focus,
  triggerEvent,
  triggerKeyEvent,
  visit,
} from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import dSelect from "discourse/tests/helpers/d-select-helper";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

const SELECTOR = ".d-editor-button-bar .post-language-selector-trigger";

const SETTINGS = {
  content_localization_enabled: true,
  available_content_localization_locales: [{ value: "en" }, { value: "fr" }],
  available_locales: [
    { name: "English", value: "en" },
    { name: "French (Français)", value: "fr" },
  ],
  allow_uncategorized_topics: true,
};

acceptance("Post language selector", function (needs) {
  needs.user();
  needs.settings(SETTINGS);

  test("keeps today's menu without new select controls", async function (assert) {
    await visit("/new-topic");

    assert.dom(`${SELECTOR}.fk-d-menu__trigger`).exists();
    assert.dom(`${SELECTOR}[role='combobox']`).doesNotExist();
  });
});

acceptance("Post language selector | new select controls", function (needs) {
  needs.user();
  needs.settings({ ...SETTINGS, enable_new_select_controls: true });

  test("is named for what it sets, and says the post's language", async function (assert) {
    await visit("/new-topic");

    assert.dSelect(SELECTOR).hasValue("none");
    assert
      .dom(SELECTOR)
      .hasAttribute("role", "combobox")
      .hasAria("label", i18n("post.localizations.post_language_selector.title"))
      .hasAttribute("tabindex", "-1")
      .hasText(i18n("post.localizations.post_language_selector.none"));
    assert.dom(`${SELECTOR} .d-icon-language`).exists();
    assert.dom(`${SELECTOR} .d-select__caret`).doesNotExist();
  });

  test("lists the languages under its header and checks the post's", async function (assert) {
    await visit("/new-topic");
    await dSelect(SELECTOR).open();

    assert.dSelect(SELECTOR).hasOptions(["en", "fr", "none"]);
    assert.deepEqual(
      findAll("[role='option']").map((row) => row.dataset.name),
      [
        "English",
        "French (Français)",
        i18n("post.localizations.post_language_selector.none"),
      ]
    );
    assert.dSelect(SELECTOR).hasSelectedOption("none");
    assert
      .dom(find("[role='listbox']").closest(".d-select__panel"))
      .includesText(i18n("post.localizations.post_language_selector.header"));
  });

  test("sets the post's language, and shows its code", async function (assert) {
    await visit("/new-topic");
    await dSelect(SELECTOR).select("fr");

    const composer = this.owner.lookup("service:composer");
    assert.strictEqual(composer.model.locale, "fr");
    assert.dSelect(SELECTOR).hasValue("fr");
    assert
      .dom(`${SELECTOR} .toolbar-popup-select__trigger-label`)
      .hasAria("hidden", "true")
      .hasText("FR");
    assert.dom(`${SELECTOR} .sr-only`).hasText("French (Français)");

    await dSelect(SELECTOR).select("none");

    assert.strictEqual(composer.model.locale, null);
    assert.dSelect(SELECTOR).hasValue("none");
  });

  test("keeps the language when Backspace is pressed on it", async function (assert) {
    await visit("/new-topic");
    await dSelect(SELECTOR).select("fr");
    await focus(SELECTOR);
    await triggerKeyEvent(SELECTOR, "keydown", "Backspace");

    assert.strictEqual(
      this.owner.lookup("service:composer").model.locale,
      "fr"
    );
    assert.dSelect(SELECTOR).hasValue("fr");
  });

  test("the toolbar's arrow keys move to it and on from it", async function (assert) {
    await visit("/new-topic");
    const buttons = findAll(".d-editor-button-bar > *");
    const index = buttons.indexOf(find(SELECTOR));
    const next = buttons.slice(index + 1).find((b) => b.matches("button"));

    await focus(next);
    await triggerEvent(next, "keydown", {
      key: "ArrowLeft",
      code: "ArrowLeft",
    });

    assert.dom(SELECTOR).isFocused("ArrowLeft reaches it");

    await triggerEvent(SELECTOR, "keydown", {
      key: "ArrowRight",
      code: "ArrowRight",
    });

    assert.dom(next).isFocused("ArrowRight leaves it");
  });

  test("opening it tells plugins the toolbar button was used", async function (assert) {
    await visit("/new-topic");
    const trigger = sinon.spy(
      this.owner.lookup("service:app-events"),
      "trigger"
    );
    await click(SELECTOR);

    assert.true(
      trigger.calledWith(
        "d-editor:toolbar-button-clicked",
        sinon.match({ id: "post-language-selector" })
      )
    );
  });
});
