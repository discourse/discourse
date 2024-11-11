import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
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
<p><aside class=\"onebox\"><article class=\"onebox-body\"><h3><a href=\"http://www.example.com/article.html\" tabindex=\"-1\">An interesting article</a></h3></article></aside><br>
This is another test <a href=\"http://www.example.com/has-title.html\" class=\"inline-onebox\" tabindex=\"-1\">This is a great title</a></p>
<p><a href=\"http://www.example.com/no-title.html\" class=\"onebox\" target=\"_blank\" tabindex=\"-1\">http://www.example.com/no-title.html</a></p>
<p>This is another test <a href=\"http://www.example.com/no-title.html\" class=\"\" tabindex=\"-1\">http://www.example.com/no-title.html</a><br>
This is another test <a href=\"http://www.example.com/has-title.html\" class=\"inline-onebox\" tabindex=\"-1\">This is a great title</a></p>
<p><aside class=\"onebox\"><article class=\"onebox-body\"><h3><a href=\"http://www.example.com/article.html\" tabindex=\"-1\">An interesting article</a></h3></article></aside></p>`);
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

  needs.pretender((server, helper) => {
    server.get("/inline-onebox", () => {
      ++requestsCount;
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
});
