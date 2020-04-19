import { acceptance } from "helpers/qunit-helpers";

acceptance("Page Publishing", {
  loggedIn: true,
  pretend(server, helper) {
    const validSlug = helper.response({ valid_slug: true });

    server.put("/pub/by-topic/280", () => {
      return helper.response({});
    });
    server.get("/pub/by-topic/280", () => {
      return helper.response({});
    });
    server.get("/pub/check-slug", req => {
      if (req.queryParams.slug === "internationalization-localization") {
        return validSlug;
      }
      return helper.response({
        valid_slug: false,
        reason: "i don't need a reason"
      });
    });
  }
});
QUnit.test("can publish a page via modal", async assert => {
  await visit("/t/internationalization-localization/280");
  await click(".topic-post:eq(0) button.show-more-actions");
  await click(".topic-post:eq(0) button.show-post-admin-menu");
  await click(".topic-post:eq(0) .publish-page");

  await fillIn(".publish-slug", "bad-slug");
  assert.ok(!exists(".valid-slug"));
  assert.ok(exists(".invalid-slug"));
  await fillIn(".publish-slug", "internationalization-localization");
  assert.ok(exists(".valid-slug"));
  assert.ok(!exists(".invalid-slug"));

  await click(".publish-page");
  assert.ok(exists(".current-url"));
});
