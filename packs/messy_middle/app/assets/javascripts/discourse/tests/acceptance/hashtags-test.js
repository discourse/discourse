import {
  acceptance,
  query,
  visible,
} from "discourse/tests/helpers/qunit-helpers";
import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";

acceptance("Category and Tag Hashtags", function (needs) {
  needs.user();
  needs.settings({
    tagging_enabled: true,
    enable_experimental_hashtag_autocomplete: false,
  });
  needs.pretender((server, helper) => {
    server.get("/hashtags", () => {
      return helper.response({
        categories: { bug: "/c/bugs" },
        tags: {
          monkey: "/tag/monkey",
          bug: "/tag/bug",
        },
      });
    });
  });

  test("hashtags are cooked properly", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");

    await fillIn(
      ".d-editor-input",
      `this is a category hashtag #bug

this is a tag hashtag #monkey

category vs tag: #bug vs #bug::tag

uppercase hashtag works too #BUG, #BUG::tag`
    );

    assert.ok(visible(".d-editor-preview"));
    assert.strictEqual(
      query(".d-editor-preview").innerHTML.trim(),
      `<p>this is a category hashtag <a href="/c/bugs" class="hashtag" tabindex=\"-1\">#<span>bug</span></a></p>
<p>this is a tag hashtag <a href="/tag/monkey" class="hashtag" tabindex=\"-1\">#<span>monkey</span></a></p>
<p>category vs tag: <a href="/c/bugs" class="hashtag" tabindex=\"-1\">#<span>bug</span></a> vs <a href="/tag/bug" class="hashtag" tabindex=\"-1\">#<span>bug</span></a></p>
<p>uppercase hashtag works too <a href="/c/bugs" class="hashtag" tabindex=\"-1\">#<span>BUG</span></a>, <a href="/tag/bug" class="hashtag" tabindex=\"-1\">#<span>BUG</span></a></p>`
    );
  });
});
