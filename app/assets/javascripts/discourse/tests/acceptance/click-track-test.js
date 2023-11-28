import { click, currentURL, visit } from "@ember/test-helpers";
import { test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Click Track", function () {
  test("Do not track mentions", async function (assert) {
    pretender.post("/clicks/track", () => {
      assert.true(false, "it should not track this click");
      return response({ success: "OK" });
    });

    await visit("/t/internationalization-localization/280");
    assert.dom(".user-card").hasNoClass("show", "card should not appear");

    await click('article[data-post-id="3651"] a.mention');
    assert.dom(".user-card").hasClass("show", "card appears");
    assert.strictEqual(
      currentURL(),
      "/t/internationalization-localization/280"
    );
  });
});
