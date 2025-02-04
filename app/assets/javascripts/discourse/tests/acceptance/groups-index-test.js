import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Groups", function () {
  test("Browsing Groups", async function (assert) {
    await visit("/g?username=eviltrout");
    assert.dom(".group-box").exists({ count: 1 }, "displays user's groups");

    await visit("/g");
    assert.dom(".group-box").exists({ count: 2 }, "displays visible groups");
    assert.dom(".group-index-join").exists("shows button to join group");
    assert
      .dom(".group-index-request")
      .exists("shows button to request for group membership");

    await click(".group-index-join");
    assert.dom(".modal.login-modal").exists("shows the login modal");

    await click(".login-modal .modal-close");
    assert.dom(".modal.login-modal").doesNotExist("closes the login modal");

    await click(".group-index-request");
    assert.dom(".modal.login-modal").exists("shows the login modal");

    await click("a[href='/g/discourse/members']");
    assert
      .dom(".group-info-name")
      .hasText("Awesome Team", "it displays the group page");

    await click(".group-index-join");
    assert.dom(".modal.login-modal").exists("shows the login modal");
  });
});
