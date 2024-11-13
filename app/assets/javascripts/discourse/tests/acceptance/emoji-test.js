import { click, fillIn, visit } from "@ember/test-helpers";
import { IMAGE_VERSION as v } from "pretty-text/emoji/version";
import { test } from "qunit";
import {
  acceptance,
  query,
  simulateKey,
  simulateKeys,
} from "discourse/tests/helpers/qunit-helpers";

acceptance("Emoji", function (needs) {
  needs.user();

  test("emoji is cooked properly", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");

    await simulateKeys(".d-editor-input", "a :blonde_wo\t");

    assert
      .dom(".d-editor-preview")
      .hasHtml(
        `<p>a <img src="/images/emoji/twitter/blonde_woman.png?v=${v}" title=":blonde_woman:" class="emoji" alt=":blonde_woman:" loading="lazy" width="20" height="20" style="aspect-ratio: 20 / 20;"></p>`
      );
  });

  test("emoji can be picked from the emoji-picker using the mouse", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");

    await simulateKeys(".d-editor-input", "an :arrow");
    // the 6th item in the list is the "more..."
    await click(".autocomplete.ac-emoji ul li:nth-of-type(6)");

    assert.dom(".emoji-picker.opened.has-filter").exists();
    await click(".emoji-picker .results img:first-of-type");

    assert
      .dom(".d-editor-preview")
      .hasHtml(
        `<p>an <img src="/images/emoji/twitter/arrow_backward.png?v=${v}" title=":arrow_backward:" class="emoji" alt=":arrow_backward:" loading="lazy" width="20" height="20" style="aspect-ratio: 20 / 20;"></p>`
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

    const editor = query(".d-editor-input");

    await simulateKeys(editor, ":s");

    assert.dom(".autocomplete.ac-emoji").doesNotExist();

    await simulateKey(editor, "w");

    assert.dom(".autocomplete.ac-emoji").exists();
  });
});
