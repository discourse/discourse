import { acceptance } from "helpers/qunit-helpers";

acceptance("Tag Hashtag", {
  loggedIn: true,
  settings: { tagging_enabled: true },
  pretend(server, helper) {
    server.get("/tags/check", () => {
      return helper.response({
        valid: [
          { value: "monkey", url: "/tag/monkey" },
          { value: "bug", url: "/tag/bug" }
        ]
      });
    });
  }
});

QUnit.test("tag is cooked properly", async assert => {
  await visit("/t/internationalization-localization/280");
  await click("#topic-footer-buttons .btn.create");

  await fillIn(".d-editor-input", "this is a tag hashtag #monkey");
  assert.equal(
    find(".d-editor-preview:visible")
      .html()
      .trim(),
    '<p>this is a tag hashtag <a href="/tag/monkey" class="hashtag">#<span>monkey</span></a></p>'
  );
});

QUnit.test(
  "tags and categories with same name are cooked properly",
  async assert => {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");

    await fillIn(".d-editor-input", "#bug vs #bug::tag");
    assert.equal(
      find(".d-editor-preview:visible")
        .html()
        .trim(),
      '<p><a href="/c/bugs" class="hashtag" data-type="category">#<span>bug</span></a> vs <a href="/tag/bug" class="hashtag" data-type="tag">#<span>bug</span></a></p>'
    );
  }
);
