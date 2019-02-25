import { acceptance } from "helpers/qunit-helpers";
import { INLINE_ONEBOX_CSS_CLASS } from "pretty-text/inline-oneboxer";

acceptance("Composer - Onebox", {
  loggedIn: true,
  settings: {
    max_oneboxes_per_post: 2,
    enable_markdown_linkify: true
  }
});

QUnit.test(
  "Preview update should respect max_oneboxes_per_post site setting",
  async assert => {
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

    assert.equal(
      find(".d-editor-preview:visible")
        .html()
        .trim(),
      `
<p><aside class=\"onebox\"><article class=\"onebox-body\"><h3><a href=\"http://www.example.com/article.html\">An interesting article</a></h3></article></aside><br>
This is another test <a href=\"http://www.example.com/has-title.html\" class=\"${INLINE_ONEBOX_CSS_CLASS}\">This is a great title</a></p>
<p><a href=\"http://www.example.com/no-title.html\" class=\"onebox\" target=\"_blank\">http://www.example.com/no-title.html</a></p>
<p>This is another test <a href=\"http://www.example.com/no-title.html\" class=\"\">http://www.example.com/no-title.html</a><br>
This is another test <a href=\"http://www.example.com/has-title.html\" class=\"${INLINE_ONEBOX_CSS_CLASS}\">This is a great title</a></p>
<p><aside class=\"onebox\"><article class=\"onebox-body\"><h3><a href=\"http://www.example.com/article.html\">An interesting article</a></h3></article></aside></p>
      `.trim()
    );
  }
);
