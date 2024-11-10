import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance, query } from "discourse/tests/helpers/qunit-helpers";

acceptance("Composer topic featured links", function (needs) {
  needs.user();
  needs.settings({
    topic_featured_link_enabled: true,
    max_topic_title_length: 80,
    enable_markdown_linkify: true,
  });

  test("onebox with title", async function (assert) {
    await visit("/");
    await click("#create-topic");
    await fillIn("#reply-title", "http://www.example.com/has-title.html");
    assert
      .dom(".d-editor-preview")
      .includesHtml("onebox", "pastes the link into the body and previews it");
    assert
      .dom(".d-editor-textarea-wrapper .popup-tip.good")
      .exists("the body is now good");
    assert.strictEqual(
      query(".title-input input").value,
      "An interesting article",
      "title is from the oneboxed article"
    );
  });

  test("onebox result doesn't include a title", async function (assert) {
    await visit("/");
    await click("#create-topic");
    await fillIn("#reply-title", "http://www.example.com/no-title.html");
    assert
      .dom(".d-editor-preview")
      .includesHtml("onebox", "pastes the link into the body and previews it");
    assert
      .dom(".d-editor-textarea-wrapper .popup-tip.good")
      .exists("the body is now good");
    assert.strictEqual(
      query(".title-input input").value,
      "http://www.example.com/no-title.html",
      "title is unchanged"
    );
  });

  test("YouTube onebox with title", async function (assert) {
    await visit("/");
    await click("#create-topic");
    await fillIn("#reply-title", "https://www.youtube.com/watch?v=dQw4w9WgXcQ");
    assert.strictEqual(
      query(".title-input input").value,
      "Rick Astley - Never Gonna Give You Up (Video)",
      "title is from the oneboxed article"
    );
  });

  test("no onebox result", async function (assert) {
    await visit("/");
    await click("#create-topic");
    await fillIn("#reply-title", "http://www.example.com/nope-onebox.html");
    assert
      .dom(".d-editor-preview")
      .includesHtml("onebox", "pastes the link into the body and previews it");
    assert
      .dom(".d-editor-textarea-wrapper .popup-tip.good")
      .exists("link is pasted into body");
    assert.strictEqual(
      query(".title-input input").value,
      "http://www.example.com/nope-onebox.html",
      "title is unchanged"
    );
  });

  test("ignore internal links", async function (assert) {
    await visit("/");
    await click("#create-topic");
    const title = "http://" + window.location.hostname + "/internal-page.html";
    await fillIn("#reply-title", title);
    assert
      .dom(".d-editor-preview")
      .doesNotIncludeHtml("onebox", "onebox preview doesn't show");
    assert.strictEqual(
      query(".d-editor-input").value.length,
      0,
      "link isn't put into the post"
    );
    assert.strictEqual(
      query(".title-input input").value,
      title,
      "title is unchanged"
    );
  });

  test("link is longer than max title length", async function (assert) {
    await visit("/");
    await click("#create-topic");
    await fillIn(
      "#reply-title",
      "http://www.example.com/has-title-and-a-url-that-is-more-than-80-characters-because-thats-good-for-seo-i-guess.html"
    );
    assert
      .dom(".d-editor-preview")
      .includesHtml("onebox", "pastes the link into the body and previews it");
    assert
      .dom(".d-editor-textarea-wrapper .popup-tip.good")
      .exists("the body is now good");
    assert.strictEqual(
      query(".title-input input").value,
      "An interesting article",
      "title is from the oneboxed article"
    );
  });

  test("onebox with title but extra words in title field", async function (assert) {
    await visit("/");
    await click("#create-topic");
    await fillIn("#reply-title", "http://www.example.com/has-title.html test");
    assert
      .dom(".d-editor-preview")
      .doesNotIncludeHtml("onebox", "onebox preview doesn't show");
    assert.strictEqual(
      query(".d-editor-input").value.length,
      0,
      "link isn't put into the post"
    );
    assert.strictEqual(
      query(".title-input input").value,
      "http://www.example.com/has-title.html test",
      "title is unchanged"
    );
  });

  test("blank title for Twitter link", async function (assert) {
    await visit("/");
    await click("#create-topic");
    await fillIn(
      "#reply-title",
      "https://twitter.com/discourse/status/1357664660724482048"
    );
    assert
      .dom(".d-editor-preview")
      .includesHtml("onebox", "pastes the link into the body and previews it");
    assert
      .dom(".d-editor-textarea-wrapper .popup-tip.good")
      .exists("the body is now good");
    assert.blank(query(".title-input input").value, "title is blank");
  });
});

acceptance(
  "Composer topic featured links when uncategorized is not allowed",
  function (needs) {
    needs.user({ moderator: true, admin: false, trust_level: 1 });
    needs.settings({
      topic_featured_link_enabled: true,
      max_topic_title_length: 80,
      enable_markdown_linkify: true,
      allow_uncategorized_topics: false,
    });

    test("Pasting a link enables the text input area", async function (assert) {
      await visit("/");
      await click("#create-topic");
      assert
        .dom(".d-editor-textarea-wrapper.disabled")
        .exists("textarea is disabled");
      await fillIn("#reply-title", "http://www.example.com/has-title.html");
      assert
        .dom(".d-editor-preview")
        .includesHtm("onebox", "pastes the link into the body and previews it");
      assert
        .dom(".d-editor-textarea-wrapper .popup-tip.good")
        .exists("the body is now good");
      assert.strictEqual(
        query(".title-input input").value,
        "An interesting article",
        "title is from the oneboxed article"
      );
      assert
        .dom(".d-editor-textarea-wrapper.disabled")
        .doesNotExist("textarea is enabled");
    });
  }
);
