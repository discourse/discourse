import { acceptance, queryAll } from "discourse/tests/helpers/qunit-helpers";
import { click, currentURL, visit } from "@ember/test-helpers";
import { test } from "qunit";

acceptance("Click Track", function (needs) {
  let tracked = false;
  needs.pretender((server, helper) => {
    server.post("/clicks/track", () => {
      tracked = true;
      return helper.response({ success: "OK" });
    });
  });

  test("Do not track mentions", async function (assert) {
    await visit("/t/internationalization-localization/280");
    assert.ok(
      queryAll(".user-card.show").length === 0,
      "card should not appear"
    );

    await click('article[data-post-id="3651"] a.mention');
    assert.ok(queryAll(".user-card.show").length === 1, "card appear");
    assert.equal(currentURL(), "/t/internationalization-localization/280");
    assert.ok(!tracked);
  });
});
