import { acceptance } from "helpers/qunit-helpers";

acceptance("Tag Hashtag", {
  loggedIn: true,
  settings: { tagging_enabled: true },
  beforeEach() {
    const response = object => {
      return [200, { "Content-Type": "application/json" }, object];
    };

    // prettier-ignore
    server.get("/tags/filter/search", () => { //eslint-disable-line
      return response({ results: [{ text: "monkey", count: 1 }] });
    });

    // prettier-ignore
    server.get("/category_hashtags/check", () => { //eslint-disable-line
      return response({ valid: [] });
    });

    // prettier-ignore
    server.get("/tags/check", () => { //eslint-disable-line
      return response({ valid: [{ value: "monkey", url: "/tags/monkey" }] });
    });
  }
});

QUnit.test("tag is cooked properly", async assert => {
  await visit("/t/internationalization-localization/280");
  await click("#topic-footer-buttons .btn.create");

  await fillIn(".d-editor-input", "this is a tag hashtag #monkey::tag");
  // TODO: Test that the autocomplete shows
  assert.equal(
    find(".d-editor-preview:visible")
      .html()
      .trim(),
    '<p>this is a tag hashtag <a href="/tags/monkey" class="hashtag">#<span>monkey</span></a></p>'
  );

  await click("#reply-control .btn.create");
  assert.equal(
    find(".topic-post:last .cooked")
      .html()
      .trim(),
    '<p>this is a tag hashtag <a href="/tags/monkey" class="hashtag">#<span>monkey</span></a></p>'
  );
});
