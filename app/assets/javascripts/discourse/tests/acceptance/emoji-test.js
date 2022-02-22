import { acceptance, queryAll } from "discourse/tests/helpers/qunit-helpers";
import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { IMAGE_VERSION as v } from "pretty-text/emoji/version";

acceptance("Emoji", function (needs) {
  needs.user();

  test("emoji is cooked properly", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");

    await fillIn(".d-editor-input", "this is an emoji :blonde_woman:");
    assert.strictEqual(
      queryAll(".d-editor-preview:visible").html().trim(),
      `<p>this is an emoji <img src="/images/emoji/google_classic/blonde_woman.png?v=${v}" title=":blonde_woman:" class="emoji" alt=":blonde_woman:" loading="lazy" width="20" height="20"></p>`
    );
  });

  test("skin toned emoji is cooked properly", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");

    await fillIn(".d-editor-input", "this is an emoji :blonde_woman:t5:");
    assert.strictEqual(
      queryAll(".d-editor-preview:visible").html().trim(),
      `<p>this is an emoji <img src="/images/emoji/google_classic/blonde_woman/5.png?v=${v}" title=":blonde_woman:t5:" class="emoji" alt=":blonde_woman:t5:" loading="lazy" width="20" height="20"></p>`
    );
  });
});
