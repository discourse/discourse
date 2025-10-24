import { click, visit } from "@ember/test-helpers";
import { IMAGE_VERSION } from "pretty-text/emoji/version";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("User Drafts", function (needs) {
  needs.user();

  test("Stream", async function (assert) {
    await visit("/u/eviltrout/activity/drafts");
    assert.dom(".user-stream-item").exists({ count: 3 }, "has drafts");

    assert
      .dom(".user-stream-item .expand-item")
      .doesNotExist("Draft doesn't show expand button");

    await click(".user-stream-item:first-child .remove-draft");
    assert.dom(".dialog-header").exists();

    await click(".dialog-footer .btn-danger");
    assert
      .dom(".user-stream-item")
      .exists({ count: 2 }, "draft removed, list length diminished by one");

    await visit("/");
    assert.dom("#create-topic").exists();
    assert
      .dom("#create-topic.open-draft")
      .doesNotExist("Open Draft button is not present");
  });

  test("Stream - resume draft", async function (assert) {
    await visit("/u/eviltrout/activity/drafts");
    assert.dom(".user-stream-item").exists("has drafts");

    await click(".user-stream-item .resume-draft");
    assert
      .dom(".d-editor-input")
      .hasValue(/A fun new topic for testing drafts./);
  });

  test("Stream - has excerpt", async function (assert) {
    await visit("/u/eviltrout/activity/drafts");
    assert.dom(".user-stream-item").exists("has drafts");
    assert.dom(".user-stream-item:nth-child(3) .category").hasText("meta");
    assert
      .dom(".user-stream-item:nth-child(3) .excerpt .cooked")
      .hasHtml(
        `here goes a reply to a PM <img src="/images/emoji/twitter/slight_smile.png?v=${IMAGE_VERSION}" title=":slight_smile:" class="emoji" alt=":slight_smile:" loading="lazy" width="20" height="20" style="aspect-ratio: 20 / 20;">`,
        "shows the excerpt"
      );

    assert
      .dom(".user-stream-item:nth-child(2) .draft-icon .d-icon")
      .hasClass("d-icon-reply", "has correct icon");
  });
});
