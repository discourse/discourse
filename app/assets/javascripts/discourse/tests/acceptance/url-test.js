import { currentURL, settled, visit } from "@ember/test-helpers";
import { test } from "qunit";
import DiscourseURL from "discourse/lib/url";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("DiscourseURL", function () {
  test("handleURL strips multiple slashes", async function (assert) {
    await visit("/");

    DiscourseURL.handleURL("/t//280");
    await settled();

    assert.strictEqual(
      currentURL(),
      "/t/internationalization-localization/280"
    );
    assert.dom("#topic-title").exists();
  });
});
