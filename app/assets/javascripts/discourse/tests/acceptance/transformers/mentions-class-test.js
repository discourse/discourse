import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("mentions-class transformer", function (needs) {
  needs.user();

  test("applying a value transformation", async function (assert) {
    await visit("/t/internationalization-localization/280");

    assert.dom(".mention[href='/u/eviltrout']").hasClass("--current");
  });
});
