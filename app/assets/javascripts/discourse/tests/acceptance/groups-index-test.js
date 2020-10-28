import { exists } from "discourse/tests/helpers/qunit-helpers";
import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  invisible,
  count,
} from "discourse/tests/helpers/qunit-helpers";

acceptance("Groups", function () {
  test("Browsing Groups", async (assert) => {
    await visit("/g?username=eviltrout");

    assert.equal(count(".group-box"), 1, "it displays user's groups");

    await visit("/g");

    assert.equal(count(".group-box"), 2, "it displays visible groups");
    assert.equal(
      find(".group-index-join").length,
      1,
      "it shows button to join group"
    );
    assert.equal(
      find(".group-index-request").length,
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

    assert.equal(
      find(".group-info-name").text().trim(),
      "Awesome Team",
      "it displays the group page"
    );

    await click(".group-index-join");

    assert.ok(exists(".modal.login-modal"), "it shows the login modal");
  });
});
