import { click, visit } from "@ember/test-helpers";
import { IMAGE_VERSION } from "pretty-text/emoji/version";
import { test } from "qunit";
import {
  acceptance,
  count,
  normalizeHtml,
  query,
  visible,
} from "discourse/tests/helpers/qunit-helpers";

acceptance("User Drafts", function (needs) {
  needs.user();

  test("Stream", async function (assert) {
    await visit("/u/eviltrout/activity/drafts");
    assert.strictEqual(count(".user-stream-item"), 3, "has drafts");

    await click(".user-stream-item:first-child .remove-draft");
    assert.ok(visible(".dialog-body"));

    await click(".dialog-footer .btn-primary");
    assert.strictEqual(
      count(".user-stream-item"),
      2,
      "draft removed, list length diminished by one"
    );

    await visit("/");
    assert.ok(visible("#create-topic"));
    assert
      .dom("#create-topic.open-draft")
      .doesNotExist("Open Draft button is not present");
  });

  test("Stream - resume draft", async function (assert) {
    await visit("/u/eviltrout/activity/drafts");
    assert.dom(".user-stream-item").exists("has drafts");

    await click(".user-stream-item .resume-draft");
    assert.strictEqual(
      query(".d-editor-input").value.trim(),
      "A fun new topic for testing drafts."
    );
  });

  test("Stream - has excerpt", async function (assert) {
    await visit("/u/eviltrout/activity/drafts");
    assert.dom(".user-stream-item").exists("has drafts");
    assert.strictEqual(
      query(".user-stream-item:nth-child(3) .category").textContent,
      "meta"
    );
    assert.strictEqual(
      normalizeHtml(
        query(".user-stream-item:nth-child(3) .excerpt").innerHTML.trim()
      ),
      normalizeHtml(
        `here goes a reply to a PM <img src="/images/emoji/twitter/slight_smile.png?v=${IMAGE_VERSION}" title=":slight_smile:" class="emoji" alt=":slight_smile:" loading="lazy" width="20" height="20" style="aspect-ratio: 20 / 20;">`
      ),
      "shows the excerpt"
    );

    assert.ok(
      query(".user-stream-item:nth-child(2) a.avatar-link").href.endsWith(
        "/u/eviltrout"
      ),
      "has correct avatar link"
    );
  });
});
