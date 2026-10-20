import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import pretender from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

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
<p><a href=\"http://www.example.com/no-title.html\" class=\"onebox\" target=\"_blank\" tabindex=\"-1\">http://www.example.com/no-title.html</a></p>
<p>This is another test <a href=\"http://www.example.com/no-title.html\" class=\"\" tabindex=\"-1\">http://www.example.com/no-title.html</a><br>
This is another test <a href=\"http://www.example.com/has-title.html\" class=\"inline-onebox\" tabindex=\"-1\">This is a great title</a></p>
<p></p><aside class=\"onebox\"><article class=\"onebox-body\"><h3><a href=\"http://www.example.com/article.html\" tabindex=\"-1\">An interesting article</a></h3></article></aside><p></p>`);
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
