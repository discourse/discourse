import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { click, tab, visit } from "@ember/test-helpers";

acceptance("Modal - Login", function () {
  test("You can tab to the login button", async function (assert) {
    await visit("/");
    await click("header .login-button");
    // you have to press the tab key twice to get to the login button
    await tab({ unRestrainTabIndex: true });
    await tab({ unRestrainTabIndex: true });
    assert.dom(".modal-footer #login-button").isFocused();
  });
});
