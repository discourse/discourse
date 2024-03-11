import { click, visit } from "@ember/test-helpers";
import { IMAGE_VERSION as v } from "pretty-text/emoji/version";
import { test } from "qunit";
import {
  acceptance,
  exists,
  normalizeHtml,
  query,
  simulateKey,
  simulateKeys,
  visible,
} from "discourse/tests/helpers/qunit-helpers";

acceptance("Emoji", function (needs) {
  needs.user();

  test("emoji is cooked properly", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");

    await simulateKeys(query(".d-editor-input"), "a :blonde_wo\t");

    assert.ok(visible(".d-editor-preview"));
    assert.strictEqual(
      normalizeHtml(query(".d-editor-preview").innerHTML.trim()),
      normalizeHtml(
        `<p>a <img src="/images/emoji/twitter/blonde_woman.png?v=${v}" title=":blonde_woman:" class="emoji" alt=":blonde_woman:" loading="lazy" width="20" height="20" style="aspect-ratio: 20 / 20;"></p>`
      )
    );
  });

  test("skin toned emoji is cooked properly", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");

    await simulateKeys(query(".d-editor-input"), "a :blonde_woman:t5:");

    assert.ok(visible(".d-editor-preview"));
    assert.strictEqual(
      normalizeHtml(query(".d-editor-preview").innerHTML.trim()),
      normalizeHtml(
        `<p>a <img src="/images/emoji/twitter/blonde_woman/5.png?v=${v}" title=":blonde_woman:t5:" class="emoji" alt=":blonde_woman:t5:" loading="lazy" width="20" height="20" style="aspect-ratio: 20 / 20;"></p>`
      )
    );
  });

  needs.settings({
    emoji_autocomplete_min_chars: 2,
  });

  test("siteSetting:emoji_autocomplete_min_chars", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");

    const editor = query(".d-editor-input");

    await simulateKeys(editor, ":s");

    assert.notOk(exists(".autocomplete.ac-emoji"));

    await simulateKey(editor, "w");

    assert.ok(exists(".autocomplete.ac-emoji"));
  });
});
