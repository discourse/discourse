import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Page Publishing", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    const validSlug = helper.response({ valid_slug: true });

    server.put("/pub/by-topic/280", () => {
      return helper.response({});
    });
    server.get("/pub/by-topic/280", () => {
      return helper.response({});
    });
    server.get("/pub/check-slug", (req) => {
      if (req.queryParams.slug === "internationalization-localization") {
        return validSlug;
      }
      return helper.response({
        valid_slug: false,
        reason: "i don't need a reason",
      });
    });
  });

  test("can publish a page via modal", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(".topic-post:nth-of-type(1) button.show-more-actions");
    await click(".topic-post:nth-of-type(1) button.show-post-admin-menu");
    await click(".publish-page");

    await fillIn(".publish-slug", "bad-slug");
    assert.dom(".valid-slug").doesNotExist();
    assert.dom(".invalid-slug").exists();
    await fillIn(".publish-slug", "internationalization-localization");
    assert.dom(".valid-slug").exists();
    assert.dom(".invalid-slug").doesNotExist();

    await click(".publish-page");
    assert.dom(".current-url").exists();
  });
});
