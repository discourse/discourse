import { acceptance } from "helpers/qunit-helpers";

acceptance("Category hashtag", { loggedIn: true });

QUnit.test("category hashtag is cooked properly", assert => {
  visit("/t/internationalization-localization/280");
  click("#topic-footer-buttons .btn.create");

  fillIn(".d-editor-input", "this is a category hashtag #bug");
  andThen(() => {
    // TODO: Test that the autocomplete shows
    assert.equal(
      find(".d-editor-preview:visible")
        .html()
        .trim(),
      '<p>this is a category hashtag <a href="/c/bugs" class="hashtag">#<span>bug</span></a></p>'
    );
  });

  click("#reply-control .btn.create");
  andThen(() => {
    assert.equal(
      find(".topic-post:last .cooked p")
        .html()
        .trim(),
      'this is a category hashtag <a href="/c/bugs" class="hashtag">#<span>bug</span></a>'
    );
  });
});
