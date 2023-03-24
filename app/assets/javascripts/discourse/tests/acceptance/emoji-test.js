import {
  acceptance,
  exists,
  normalizeHtml,
  query,
  visible,
} from "discourse/tests/helpers/qunit-helpers";
import { click, fillIn, triggerKeyEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { IMAGE_VERSION as v } from "pretty-text/emoji/version";

acceptance("Emoji", function (needs) {
  needs.user();

  test("emoji is cooked properly", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");

    await fillIn(".d-editor-input", "this is an emoji :blonde_woman:");
    assert.ok(visible(".d-editor-preview"));
    assert.strictEqual(
      normalizeHtml(query(".d-editor-preview").innerHTML.trim()),
      normalizeHtml(
        `<p>this is an emoji <img src="/images/emoji/twitter/blonde_woman.png?v=${v}" title=":blonde_woman:" class="emoji" alt=":blonde_woman:" loading="lazy" width="20" height="20" style="aspect-ratio: 20 / 20;"></p>`
      )
    );
  });

  test("skin toned emoji is cooked properly", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");

    await fillIn(".d-editor-input", "this is an emoji :blonde_woman:t5:");

    assert.ok(visible(".d-editor-preview"));
    assert.strictEqual(
      normalizeHtml(query(".d-editor-preview").innerHTML.trim()),
      normalizeHtml(
        `<p>this is an emoji <img src="/images/emoji/twitter/blonde_woman/5.png?v=${v}" title=":blonde_woman:t5:" class="emoji" alt=":blonde_woman:t5:" loading="lazy" width="20" height="20" style="aspect-ratio: 20 / 20;"></p>`
      )
    );
  });

  needs.settings({
    emoji_autocomplete_min_chars: 2,
  });

  test("siteSetting:emoji_autocomplete_min_chars", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");

    await fillIn(".d-editor-input", ":s");
    await triggerKeyEvent(".d-editor-input", "keyup", "ArrowDown"); // ensures a keyup is triggered

    assert.notOk(exists(".autocomplete.ac-emoji"));

    await fillIn(".d-editor-input", ":sw");
    await triggerKeyEvent(".d-editor-input", "keyup", "ArrowDown"); // ensures a keyup is triggered

    assert.ok(exists(".autocomplete.ac-emoji"));
  });
});
