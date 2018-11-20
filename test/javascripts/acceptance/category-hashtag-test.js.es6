import { acceptance } from "helpers/qunit-helpers";

acceptance("Category hashtag", { loggedIn: true });

QUnit.test("category hashtag is cooked properly", async assert => {
  await visit("/t/internationalization-localization/280");
  await click("#topic-footer-buttons .btn.create");

  await fillIn(".d-editor-input", "this is a category hashtag #bug");
  // TODO: Test that the autocomplete shows
  assert.equal(
    find(".d-editor-preview:visible")
      .html()
      .trim(),
    '<p>this is a category hashtag <a href="/c/bugs" class="hashtag">#<span>bug</span></a></p>'
  );

  await click("#reply-control .btn.create");
  assert.equal(
    find(".topic-post:last .cooked p")
      .html()
      .trim(),
    'this is a category hashtag <a href="/c/bugs" class="hashtag">#<span>bug</span></a>'
  );
});
