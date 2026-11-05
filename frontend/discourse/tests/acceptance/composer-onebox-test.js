import { click, fillIn, visit } from "@ember/test-helpers";
import { applyCachedInlineOnebox } from "pretty-text/inline-oneboxer";
import { setLocalCache } from "pretty-text/oneboxer-cache";
import { test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import pretender from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

function cacheOnebox(name, text) {
  const onebox = document.createElement("aside");
  onebox.className = "onebox";
  onebox.textContent = text;
  setLocalCache(`http://www.example.com/${name}.html`, onebox);
}

acceptance("Composer - Onebox", function (needs) {
  needs.user();
  needs.settings({
    max_oneboxes_per_post: 2,
    enable_markdown_linkify: true,
  });

  test("Preview update should respect max_oneboxes_per_post site setting", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");

    await fillIn(
      ".d-editor-input",
      `
http://www.example.com/has-title.html
This is another test http://www.example.com/has-title.html

http://www.example.com/no-title.html

This is another test http://www.example.com/no-title.html
This is another test http://www.example.com/has-title.html

http://www.example.com/has-title.html
        `
    );

    assert.dom(".d-editor-preview").exists();
    assert.dom(".d-editor-preview").hasHtml(`
<p></p><aside class=\"onebox\"><article class=\"onebox-body\"><h3><a href=\"http://www.example.com/article.html\" tabindex=\"-1\">An interesting article</a></h3></article></aside><br>
This is another test <a href=\"http://www.example.com/has-title.html\" class=\"inline-onebox\" tabindex=\"-1\">This is a great title</a><p></p>
<p><a href=\"http://www.example.com/no-title.html\" tabindex=\"-1\">http://www.example.com/no-title.html</a></p>
<p>This is another test <a href=\"http://www.example.com/no-title.html\" tabindex=\"-1\">http://www.example.com/no-title.html</a><br>
This is another test <a href=\"http://www.example.com/has-title.html\" tabindex=\"-1\">http://www.example.com/has-title.html</a></p>
<p><a href=\"http://www.example.com/has-title.html\" tabindex=\"-1\">http://www.example.com/has-title.html</a></p>`);
  });

  test("cached oneboxes respect max_oneboxes_per_post site setting", async function (assert) {
    ["first", "second", "third"].forEach((name) => cacheOnebox(name, name));
    applyCachedInlineOnebox("http://www.example.com/inline.html", {
      title: "Inline title",
    });

    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");
    await fillIn(
      ".d-editor-input",
      `http://www.example.com/first.html

http://www.example.com/second.html

http://www.example.com/third.html

See http://www.example.com/inline.html`
    );

    assert.dom(".d-editor-preview aside.onebox").exists({ count: 2 });
    assert.dom(".d-editor-preview a.inline-onebox").doesNotExist();
  });

  test("cached oneboxes do not take the slots of earlier oneboxes", async function (assert) {
    ["first", "second"].forEach((name) => cacheOnebox(name, `Cached ${name}`));

    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");
    await fillIn(
      ".d-editor-input",
      `http://www.example.com/has-title.html

http://www.example.com/first.html

http://www.example.com/second.html`
    );

    assert.dom(".d-editor-preview aside.onebox").exists({ count: 2 });
    assert.dom(".d-editor-preview").includesText("An interesting article");
    assert.dom(".d-editor-preview").includesText("Cached first");
    assert.dom(".d-editor-preview").doesNotIncludeText("Cached second");
  });

  test("repeated oneboxes each take a slot", async function (assert) {
    cacheOnebox("first", "Cached first");

    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");
    await fillIn(
      ".d-editor-input",
      `http://www.example.com/first.html

http://www.example.com/first.html

http://www.example.com/has-title.html`
    );

    assert.dom(".d-editor-preview aside.onebox").exists({ count: 2 });
    assert
      .dom(".d-editor-preview a[href='http://www.example.com/has-title.html']")
      .doesNotHaveClass("onebox");
    assert
      .dom(".d-editor-preview")
      .doesNotIncludeText("An interesting article");
  });

  test("cached oneboxes that are not asides take a slot", async function (assert) {
    const video = document.createElement("div");
    video.className = "youtube-onebox";
    setLocalCache("http://www.example.com/first.html", video);

    cacheOnebox("second", "");

    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");
    await fillIn(
      ".d-editor-input",
      `http://www.example.com/first.html

http://www.example.com/second.html

http://www.example.com/has-title.html`
    );

    assert.dom(".d-editor-preview .youtube-onebox").exists();
    assert.dom(".d-editor-preview aside.onebox").exists({ count: 1 });
    assert
      .dom(".d-editor-preview")
      .doesNotIncludeText("An interesting article");
  });

  test("decorates oneboxes once they load", async function (assert) {
    withPluginApi((api) => {
      api.decorateCookedElement((element) =>
        element
          .querySelectorAll("aside.onebox")
          .forEach((onebox) => onebox.classList.add("decorated"))
      );
    });

    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");
    await fillIn(".d-editor-input", "http://www.example.com/has-title.html");

    assert.dom(".d-editor-preview aside.onebox.decorated").exists();
  });

  test("keeps inline onebox titles that load after a onebox", async function (assert) {
    pretender.get(
      "/inline-onebox",
      () => [
        200,
        { "Content-Type": "application/html" },
        '{"inline-oneboxes":[{"url":"http://www.example.com/late-title.html","title":"A late title"}]}',
      ],
      500
    );

    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");
    await fillIn(
      ".d-editor-input",
      "http://www.example.com/no-title.html\n\nSee http://www.example.com/late-title.html"
    );

    assert.dom(".d-editor-preview .inline-onebox").hasText("A late title");
  });
});

acceptance("Composer - Inline Onebox", function (needs) {
  needs.user();
  needs.settings({
    max_oneboxes_per_post: 2,
    enable_markdown_linkify: true,
    markdown_linkify_tlds: "com",
  });

  let requestsCount;
  let requestParams;

  needs.pretender((server, helper) => {
    server.get("/inline-onebox", (request) => {
      ++requestsCount;
      requestParams = request.queryParams;
      return helper.response({ "inline-oneboxes": [] });
    });
  });

  test("Uses cached inline onebox", async function (assert) {
    requestsCount = 0;

    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");

    await fillIn(".d-editor-input", `Test www.example.com/page`);
    assert.strictEqual(requestsCount, 1);
    assert
      .dom(".d-editor-preview")
      .hasHtml(
        '<p>Test <a href="http://www.example.com/page" class="inline-onebox-loading" tabindex="-1">www.example.com/page</a></p>'
      );

    await fillIn(".d-editor-input", `Test www.example.com/page Test`);
    assert.strictEqual(requestsCount, 1);
    assert
      .dom(".d-editor-preview")
      .hasHtml(
        '<p>Test <a href="http://www.example.com/page" tabindex="-1">www.example.com/page</a> Test</p>'
      );
  });

  test("requests titles in the context of the composed topic", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");
    await fillIn(".d-editor-input", `Test www.example.com/page`);

    const { model } = this.owner.lookup("service:composer");
    assert.strictEqual(requestParams.topic_id, String(model.topic.id));
    assert.strictEqual(requestParams.category_id, String(model.category.id));
  });
});
