import {
  acceptance,
  count,
  exists,
  invisible,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";

acceptance("Groups", function () {
  test("Browsing Groups", async function (assert) {
    await visit("/g?username=eviltrout");
    assert.strictEqual(count(".group-box"), 1, "it displays user's groups");

    await visit("/g");
    assert.strictEqual(count(".group-box"), 2, "it displays visible groups");
    assert.strictEqual(
      count(".group-index-join"),
      1,
      "it shows button to join group"
    );
    assert.strictEqual(
      count(".group-index-request"),
      1,
      "it shows button to request for group membership"
    );

    await click(".group-index-join");
    assert.ok(exists(".modal.login-modal"), "it shows the login modal");

    await click(".login-modal .close");
    assert.ok(invisible(".modal.login-modal"), "it closes the login modal");

    await click(".group-index-request");
    assert.ok(exists(".modal.login-modal"), "it shows the login modal");

    await click("a[href='/g/discourse/members']");
    assert.strictEqual(
      query(".group-info-name").innerText.trim(),
      "Awesome Team",
      "it displays the group page"
    );

    await click(".group-index-join");
    assert.ok(exists(".modal.login-modal"), "it shows the login modal");
  });
});
