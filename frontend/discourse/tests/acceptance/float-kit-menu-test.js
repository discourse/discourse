import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("FloatKit - DMenu", function () {
  test("an open menu closes on route change", async function (assert) {
    await visit("/");

    await this.owner
      .lookup("service:menu")
      .show(document.querySelector("#site-logo"), {
        identifier: "route-change-test",
        content: "content",
      });

    assert.dom("[data-identifier='route-change-test']").exists();

    await visit("/u/eviltrout");

    assert.dom("[data-identifier='route-change-test']").doesNotExist();
  });
});
