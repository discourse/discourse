import { getOwner } from "@ember/owner";
import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Acceptance | Globals", function () {
  test("Globals function as expected", async function (assert) {
    await visit("/");

    assert.notStrictEqual(
      window.Discourse,
      undefined,
      "window.Discourse is present"
    );

    assert.strictEqual(
      window.Discourse,
      getOwner(this),
      "matches the expected application instance"
    );
  });
});
