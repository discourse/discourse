import {
  acceptance,
  count,
  exists,
  query,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import I18n from "I18n";
import selectKit from "discourse/tests/helpers/select-kit-helper";

acceptance("Admin - Watched Words", function (needs) {
  needs.user();

  test("list words in groups", async function (assert) {
    await visit("/admin/customize/watched_words/action/block");

    assert.ok(!exists(".admin-watched-words .alert-error"));

    assert.ok(
      !exists(".watched-words-list"),
      "Don't show bad words by default."
    );

    assert.ok(
      !exists(".watched-words-list .watched-word"),
      "Don't show bad words by default."
    );

    await fillIn(".admin-controls .controls input[type=text]", "li");

    assert.strictEqual(
      count(".watched-words-list .watched-word"),
      1,
      "When filtering, show words even if checkbox is unchecked."
    );

    await fillIn(".admin-controls .controls input[type=text]", "");

    assert.ok(
      !exists(".watched-words-list .watched-word"),
      "Clearing the filter hides words again."
    );

    await click(".show-words-checkbox");

    assert.ok(
      exists(".watched-words-list .watched-word"),
      "Always show the words when checkbox is checked."
    );

    await click(".nav-stacked .censor a");

    assert.ok(exists(".watched-words-list"));
    assert.ok(!exists(".watched-words-list .watched-word"), "Empty word list.");
  });

  test("add words", async function (assert) {
    await visit("/admin/customize/watched_words/action/block");

    await click(".show-words-checkbox");
    await fillIn(".watched-word-form input", "poutine");
    await click(".watched-word-form button");

    let found = [];
    [...queryAll(".watched-words-list .watched-word")].forEach((elem) => {
      if (elem.innerText.trim() === "poutine") {
        found.push(true);
      }
    });

    assert.strictEqual(found.length, 1);
    assert.strictEqual(count(".watched-words-list .case-sensitive"), 0);
  });

  test("add case-sensitive words", async function (assert) {
    await visit("/admin/customize/watched_words/action/block");
    const submitButton = query(".watched-word-form button");
    assert.strictEqual(
      submitButton.disabled,
      true,
      "Add button is disabled by default"
    );
    await click(".show-words-checkbox");
    await fillIn(".watched-word-form input", "Discourse");
    await click(".case-sensitivity-checkbox");
    assert.strictEqual(
      submitButton.disabled,
      false,
      "Add button should no longer be disabled after input is filled"
    );
    await click(submitButton);

    assert
      .dom(".watched-words-list .watched-word")
      .hasText(`Discourse ${I18n.t("admin.watched_words.case_sensitive")}`);

    await fillIn(".watched-word-form input", "discourse");
    await click(".case-sensitivity-checkbox");
    await click(submitButton);

    assert
      .dom(".watched-words-list .watched-word")
      .hasText(`discourse ${I18n.t("admin.watched_words.case_sensitive")}`);
  });

  test("remove words", async function (assert) {
    await visit("/admin/customize/watched_words/action/block");
    await click(".show-words-checkbox");

    let wordId = null;

    [...queryAll(".watched-words-list .watched-word")].forEach((elem) => {
      if (elem.innerText.trim() === "anise") {
        wordId = elem.getAttribute("id");
      }
    });

    await click(`#${wordId} .delete-word-record`);

    assert.strictEqual(count(".watched-words-list .watched-word"), 2);
  });

  test("test modal - replace", async function (assert) {
    await visit("/admin/customize/watched_words/action/replace");
    await click(".watched-word-test");
    await fillIn(".modal-body textarea", "Hi there!");
    assert.strictEqual(query(".modal-body li .match").innerText, "Hi");
    assert.strictEqual(query(".modal-body li .replacement").innerText, "hello");
  });

  test("test modal - tag", async function (assert) {
    await visit("/admin/customize/watched_words/action/tag");
    await click(".watched-word-test");
    await fillIn(".modal-body textarea", "Hello world!");
    assert.strictEqual(query(".modal-body li .match").innerText, "Hello");
    assert.strictEqual(query(".modal-body li .tag").innerText, "greeting");
  });

  test("emoji replacement", async function (assert) {
    await visit("/admin/customize/watched_words/action/replace");
    await click(".watched-word-test");
    await fillIn(".modal-body textarea", "Hi there!");
    assert.strictEqual(query(".modal-body li .match").innerText, "Hi");
    assert.strictEqual(query(".modal-body li .replacement").innerText, "hello");
  });
});

acceptance("Admin - Watched Words - Emoji Replacement", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    server.get("/admin/customize/watched_words.json", () => {
      return helper.response({
        actions: ["block", "censor", "require_approval", "flag", "replace"],
        words: [
          {
            id: 81,
            word: "betis",
            regexp: "(?:\\W|^)(betis)(?=\\W|$)",
            replacement: ":poop:",
            action: "replace",
            case_sensitive: false,
          },
        ],
        compiled_regular_expressions: {
          block: null,
          censor: null,
          require_approval: null,
          flag: null,
          replace: [
            {
              "(?:\\W|^)(betis)(?=\\W|$)": {
                case_sensitive: false,
              },
            },
          ],
        },
      });
    });
  });

  test("emoji renders successfully after replacement", async function (assert) {
    await visit("/admin/customize/watched_words/action/replace");
    // await this.pauseTest();
    await visit("/");
    await click("#create-topic");
    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);
    await fillIn("#reply-title", "Watched Words Replacement Test");
    await fillIn(".d-editor-input", "betis betis betis");
    const cooked = query(".d-editor-preview p");
    const threeEmojis = `<img src="/images/emoji/twitter/poop.png?v=12" title=":poop:" class="emoji only-emoji" alt=":poop:" loading="lazy" width="20" height="20" style="aspect-ratio: 20 / 20;"> <img src="/images/emoji/twitter/poop.png?v=12" title=":poop:" class="emoji only-emoji" alt=":poop:" loading="lazy" width="20" height="20" style="aspect-ratio: 20 / 20;"> <img src="/images/emoji/twitter/poop.png?v=12" title=":poop:" class="emoji only-emoji" alt=":poop:" loading="lazy" width="20" height="20" style="aspect-ratio: 20 / 20;">`;
    assert.strictEqual(
      cooked.children.length,
      3,
      "3 elements have been rendered"
    );
    assert.strictEqual(
      cooked.innerHTML,
      threeEmojis,
      "3 emojis have been rendered"
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
    assert.strictEqual(count(".admin-watched-words .alert-error"), 1);
  });
});
