import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { click, currentURL, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";

acceptance("Jump to", function (needs) {
  needs.user();
  needs.mobileView();

  needs.pretender((server, helper) => {
    server.get("/t/280/excerpts.json", () => helper.response([]));
    server.get("/t/280/3.json", () => helper.response({}));
    server.get("/posts/by-date/280/:date", (req) => {
      if (req.params["date"] === "2014-02-24") {
        return helper.response({
          post_number: 3,
        });
      }

      return helper.response(404, null);
    });
  });

  test("default", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("nav#topic-progress .nums");
    await click("button.jump-to-post");

    assert.dom(".jump-to-post-modal").exists("it shows the modal");

    await fillIn("input.date-picker", "2014-02-24");
    await click(".jump-to-post-modal .btn-primary");

    assert.strictEqual(
      currentURL(),
      "/t/internationalization-localization/280/3",
      "it jumps to the correct post"
    );
  });
});
