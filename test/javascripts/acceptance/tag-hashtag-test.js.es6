import { acceptance } from "helpers/qunit-helpers";

acceptance("Tag Hashtag", {
  loggedIn: true,
  settings: { tagging_enabled: true },
  pretend(server, helper) {
    server.get("/tags/filter/search", () => {
      return helper.response({ results: [{ text: "monkey", count: 1 }] });
    });

    server.get("/tags/check", () => {
      return helper.response({
        valid: [{ value: "monkey", url: "/tags/monkey" }]
      });
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
