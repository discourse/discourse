import { acceptance } from "helpers/qunit-helpers";

acceptance("Category hashtag", {
  loggedIn: true,
  setup() {
    const response = (object) => {
      return [
        200,
        {"Content-Type": "application/json"},
        object
      ];
    };

  }
});

test("category hashtag is cooked properly", () => {
  visit("/t/internationalization-localization/280");
  click('#topic-footer-buttons .btn.create');

  fillIn('.d-editor-input', "this is a category hashtag #bug");
  andThen(() => {
    // TODO: Test that the autocomplete shows
    equal(find('.d-editor-preview:visible').html().trim(), "<p>this is a category hashtag <a href=\"/c/bugs\" class=\"hashtag\">#<span>bug</span></a></p>");
  });

  click('#reply-control .btn.create');
  andThen(() => {
    equal(find('.topic-post:last .cooked p').html().trim(), "this is a category hashtag <a href=\"/c/bugs\" class=\"hashtag\">#<span>bug</span></a>");
  });
});
