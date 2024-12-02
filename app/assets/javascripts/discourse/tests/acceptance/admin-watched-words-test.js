import { click, fillIn, triggerKeyEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance, queryAll } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

acceptance("Admin - Watched Words", function (needs) {
  needs.user();

  test("list words in groups", async function (assert) {
    await visit("/admin/customize/watched_words/action/block");

    assert.dom(".admin-watched-words .alert-error").doesNotExist();

    assert
      .dom(".watched-words-list")
      .doesNotExist("Don't show bad words by default.");

    assert
      .dom(".watched-words-list .watched-word")
      .doesNotExist("Don't show bad words by default.");

    await fillIn(".admin-controls .controls input[type=text]", "li");

    assert
      .dom(".watched-words-list .watched-word")
      .exists(
        { count: 1 },
        "When filtering, show words even if checkbox is unchecked."
      );

    await fillIn(".admin-controls .controls input[type=text]", "");

    assert
      .dom(".watched-words-list .watched-word")
      .doesNotExist("Clearing the filter hides words again.");

    await click(".show-words-checkbox");

    assert
      .dom(".watched-words-list .watched-word")
      .exists("Always show the words when checkbox is checked.");

    await click(".nav-stacked .censor a");

    assert.dom(".watched-words-list").exists();
    assert
      .dom(".watched-words-list .watched-word")
      .doesNotExist("Empty word list.");
  });

  test("add words", async function (assert) {
    await visit("/admin/customize/watched_words/action/block");

    await click(".show-words-checkbox");
    await click(".select-kit-header.multi-select-header");

    await fillIn(".select-kit-filter input", "poutine");
    await triggerKeyEvent(".select-kit-filter input", "keydown", "Enter");

    await fillIn(".select-kit-filter input", "cheese");
    await triggerKeyEvent(".select-kit-filter input", "keydown", "Enter");

    assert
      .dom(".select-kit-header-wrapper .formatted-selection")
      .hasText("poutine, cheese", "has the correct words in the input field");

    await click(".watched-word-form .btn-primary");

    const words = [...queryAll(".watched-words-list .watched-word span")].map(
      (elem) => elem.innerText.trim()
    );

    assert.true(words.includes("poutine"), "has word 'poutine'");
    assert.true(words.includes("cheese"), "has word 'cheese'");
    assert.dom(".watched-words-list .case-sensitive").doesNotExist();
  });

  test("add case-sensitive words", async function (assert) {
    await visit("/admin/customize/watched_words/action/block");
    assert
      .dom(".watched-word-form .btn-primary")
      .isDisabled("Add button is disabled by default");
    await click(".show-words-checkbox");

    await click(".select-kit-header.multi-select-header");
    await fillIn(".select-kit-filter input", "Discourse");
    await triggerKeyEvent(".select-kit-filter input", "keydown", "Enter");

    await click(".case-sensitivity-checkbox");
    assert
      .dom(".watched-word-form .btn-primary")
      .isEnabled(
        "Add button should no longer be disabled after input is filled"
      );

    await click(".watched-word-form .btn-primary");
    assert
      .dom(".watched-words-list .watched-word span:first-of-type")
      .hasText("Discourse");
    assert
      .dom(".watched-words-list .watched-word .case-sensitive")
      .hasText(i18n("admin.watched_words.case_sensitive"));

    await click(".select-kit-header.multi-select-header");
    await fillIn(".select-kit-filter input", "discourse");
    await triggerKeyEvent(".select-kit-filter input", "keydown", "Enter");
    await click(".case-sensitivity-checkbox");
    await click(".watched-word-form .btn-primary");

    assert
      .dom(".watched-words-list .watched-word span:first-of-type")
      .hasText("discourse");
    assert
      .dom(".watched-words-list .watched-word .case-sensitive")
      .hasText(i18n("admin.watched_words.case_sensitive"));
  });

  test("remove words", async function (assert) {
    await visit("/admin/customize/watched_words/action/block");
    await click(".show-words-checkbox");

    assert.dom(".watched-words-list .watched-word").exists({ count: 3 });

    await click(`.delete-word-record`);

    assert.dom(".watched-words-list .watched-word").exists({ count: 2 });
  });

  test("test modal - replace", async function (assert) {
    await visit("/admin/customize/watched_words/action/replace");
    await click(".watched-word-test");
    await fillIn(".d-modal__body textarea", "Hi there!");

    assert.dom(".d-modal__body li .match").hasText("Hi");
    assert.dom(".d-modal__body li .replacement").hasText("hello");
  });

  test("test modal - tag", async function (assert) {
    await visit("/admin/customize/watched_words/action/tag");
    await click(".watched-word-test");
    await fillIn(".d-modal__body textarea", "Hello world!");

    assert.dom(".d-modal__body li .match").hasText("Hello");
    assert.dom(".d-modal__body li .tag").hasText("greeting");
  });

  test("showing/hiding words - tag", async function (assert) {
    await visit("/admin/customize/watched_words/action/tag");

    await click(".show-words-checkbox");

    assert.dom(".watched-word").hasText("​ hello → greeting");

    await click(".show-words-checkbox");

    assert.dom(".watched-word").doesNotExist();
  });
});

acceptance("Admin - Watched Words - Emoji Replacement", function (needs) {
  needs.user();
  needs.site({
    watched_words_replace: {
      "(?:\\W|^)(betis)(?=\\W|$)": {
        replacement: ":poop:",
        case_sensitive: false,
      },
    },
  });

  test("emoji renders successfully after replacement", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("button.reply-to-post");
    await fillIn(".d-editor-input", "betis betis betis");

    const emojis = [
      ...document.querySelector(".d-editor-preview p").children,
    ].filter((child) => child.nodeName === "IMG");

    assert.strictEqual(emojis.length, 3, "three emojis have been rendered");
    assert.true(
      emojis.every((emoji) => emoji.title === ":poop:"),
      "all emojis are :poop:"
    );
  });
});

acceptance("Admin - Watched Words - Bad regular expressions", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    server.get("/admin/customize/watched_words.json", () => {
      return helper.response({
        actions: ["block", "censor", "require_approval", "flag", "replace"],
        words: [
          {
            id: 1,
            word: "[.*",
            regexp: "[.*",
            action: "block",
          },
        ],
        compiled_regular_expressions: {
          block: null,
          censor: null,
          require_approval: null,
          flag: null,
          replace: null,
        },
      });
    });
  });

  test("shows an error message if regex is invalid", async function (assert) {
    await visit("/admin/customize/watched_words/action/block");
    assert.dom(".admin-watched-words .alert-error").exists({ count: 1 });
  });
});
