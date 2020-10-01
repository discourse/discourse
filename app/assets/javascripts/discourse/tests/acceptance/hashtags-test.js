import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Category and Tag Hashtags", {
  loggedIn: true,
  settings: { tagging_enabled: true },
  pretend(server, helper) {
    server.get("/hashtags", () => {
      return helper.response({
        categories: { bug: "/c/bugs" },
        tags: {
          monkey: "/tag/monkey",
          bug: "/tag/bug",
        },
      });
    });
  },
});

QUnit.test("hashtags are cooked properly", async (assert) => {
  await visit("/t/internationalization-localization/280");
  await click("#topic-footer-buttons .btn.create");

  await fillIn(
    ".d-editor-input",
    `this is a category hashtag #bug

this is a tag hashtag #monkey

category vs tag: #bug vs #bug::tag`
  );

  assert.equal(
    find(".d-editor-preview:visible").html().trim(),
    `<p>this is a category hashtag <a href="/c/bugs" class="hashtag">#<span>bug</span></a></p>
<p>this is a tag hashtag <a href="/tag/monkey" class="hashtag">#<span>monkey</span></a></p>
<p>category vs tag: <a href="/c/bugs" class="hashtag">#<span>bug</span></a> vs <a href="/tag/bug" class="hashtag">#<span>bug</span></a></p>`
  );
});
