import { click, fillIn, visit } from "@ember/test-helpers";
import { IMAGE_VERSION as v } from "pretty-text/emoji/version";
import { test } from "qunit";
import emojiPicker from "discourse/tests/helpers/emoji-picker-helper";
import {
  acceptance,
  simulateKey,
  simulateKeys,
} from "discourse/tests/helpers/qunit-helpers";

acceptance("Emoji", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    server.get("/emojis/search-aliases.json", () => {
      return helper.response([]);
    });
    server.get("/drafts/topic_280.json", function () {
      return helper.response(200, { draft: null });
    });
  });

  test("emoji is cooked properly", async function (assert) {
    this.siteSettings.floatkit_autocomplete_composer = false;
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");

    await simulateKeys(".d-editor-input", "a :blonde_woman\t");
    assert
      .dom(".d-editor-preview")
      .hasHtml(
        `<p>a <img src="/images/emoji/twitter/blonde_woman.png?v=${v}" title=":blonde_woman:" class="emoji" alt=":blonde_woman:" loading="lazy" width="20" height="20" style="aspect-ratio: 20 / 20;"></p>`
      );
  });

  test("emoji can be picked from the emoji-picker using the mouse", async function (assert) {
    this.siteSettings.floatkit_autocomplete_composer = false;
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");

    await simulateKeys(".d-editor-input", "a :man_b");

    // the 6th item in the list is the "more..."
    await click(".autocomplete.ac-emoji ul li:nth-of-type(6) a");
    await emojiPicker().select("man_biking");

    assert
      .dom(".d-editor-preview")
      .hasHtml(
        `<p>a <img src="/images/emoji/twitter/man_biking.png?v=${v}" title=":man_biking:" class="emoji" alt=":man_biking:" loading="lazy" width="20" height="20" style="aspect-ratio: 20 / 20;"></p>`
      );
  });

  test("skin toned emoji is cooked properly", async function (assert) {
    this.siteSettings.floatkit_autocomplete_composer = false;
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");

    await fillIn(".d-editor-input", "a :blonde_woman:t5:");

    assert
      .dom(".d-editor-preview")
      .hasHtml(
        `<p>a <img src="/images/emoji/twitter/blonde_woman/5.png?v=${v}" title=":blonde_woman:t5:" class="emoji" alt=":blonde_woman:t5:" loading="lazy" width="20" height="20" style="aspect-ratio: 20 / 20;"></p>`
      );
  });

  needs.settings({ emoji_autocomplete_min_chars: 2 });

  test("siteSetting:emoji_autocomplete_min_chars", async function (assert) {
    this.siteSettings.floatkit_autocomplete_composer = false;
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");

    await simulateKeys(".d-editor-input", ":s");
    assert.dom(".autocomplete.ac-emoji").doesNotExist();

    await simulateKey(".d-editor-input", "w");
    assert.dom(".autocomplete.ac-emoji").exists();
  });
});

acceptance("Emoji with floatkit", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    server.get("/emojis/search-aliases.json", () => {
      return helper.response([]);
    });
    server.get("/drafts/topic_280.json", function () {
      return helper.response(200, { draft: null });
    });
  });

  test("emoji is cooked properly", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");

    await simulateKeys(".d-editor-input", "a :blonde_woman\t");

    assert
      .dom(".d-editor-preview")
      .hasHtml(
        `<p>a <img src="/images/emoji/twitter/blonde_woman.png?v=${v}" title=":blonde_woman:" class="emoji" alt=":blonde_woman:" loading="lazy" width="20" height="20" style="aspect-ratio: 20 / 20;"></p>`
      );
  });

  test("emoji can be picked from the emoji-picker using the mouse", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");

    await simulateKeys(".d-editor-input", "a :man_b");

    // the 6th item in the list is the "more..."
    await click(".autocomplete.ac-emoji ul li:nth-of-type(6) a");
    await emojiPicker().select("man_biking");

    assert
      .dom(".d-editor-preview")
      .hasHtml(
        `<p>a <img src="/images/emoji/twitter/man_biking.png?v=${v}" title=":man_biking:" class="emoji" alt=":man_biking:" loading="lazy" width="20" height="20" style="aspect-ratio: 20 / 20;"></p>`
      );
  });

  test("skin toned emoji is cooked properly", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");

    await fillIn(".d-editor-input", "a :blonde_woman:t5:");

    assert
      .dom(".d-editor-preview")
      .hasHtml(
        `<p>a <img src="/images/emoji/twitter/blonde_woman/5.png?v=${v}" title=":blonde_woman:t5:" class="emoji" alt=":blonde_woman:t5:" loading="lazy" width="20" height="20" style="aspect-ratio: 20 / 20;"></p>`
      );
  });

  needs.settings({ emoji_autocomplete_min_chars: 2 });

  test("siteSetting:emoji_autocomplete_min_chars", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");

    await simulateKeys(".d-editor-input", ":s");
    assert.dom(".autocomplete.ac-emoji").doesNotExist();

    await simulateKey(".d-editor-input", "w");
    assert.dom(".autocomplete.ac-emoji").exists();
  });
});
