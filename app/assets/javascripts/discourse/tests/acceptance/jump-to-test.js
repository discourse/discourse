import { exists } from "discourse/tests/helpers/qunit-helpers";
import { click, fillIn, visit, currentURL } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Jump to", function (needs) {
  needs.user();
  needs.mobileView();

  needs.pretender((server, helper) => {
    server.get("/t/280/excerpts.json", () => helper.response(200, []));
    server.get("/t/280/3.json", () => helper.response(200, {}));
    server.get("/posts/by-date/280/:date", (req) => {
      if (req.params["date"] === "2014-02-24") {
        return helper.response(200, {
          post_number: 3,
        });
      }

      return helper.response(404, null);
    });
  });

  test("default", async (assert) => {
    await visit("/t/internationalization-localization/280");
    await click("nav#topic-progress .nums");
    await click("button.jump-to-post");

    assert.ok(exists(".jump-to-post-modal"), "it shows the modal");

    await fillIn("input.date-picker", "2014-02-24");
    await click(".jump-to-post-modal .btn-primary");

    assert.equal(
      currentURL(),
      "/t/internationalization-localization/280/3",
      "it jumps to the correct post"
    );
  });

  test("invalid date", async (assert) => {
    await visit("/t/internationalization-localization/280");
    await click("nav#topic-progress .nums");
    await click("button.jump-to-post");
    await fillIn("input.date-picker", "2094-02-24");
    await click(".jump-to-post-modal .btn-primary");

    assert.equal(
      currentURL(),
      "/t/internationalization-localization/280/20",
      "it jumps to the last post if no post found"
    );
  });
});
