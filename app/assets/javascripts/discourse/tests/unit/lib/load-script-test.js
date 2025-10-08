import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { cacheBuster } from "discourse/lib/load-script";

module("Unit | Utility | load-script", function (hooks) {
  setupTest(hooks);

  test("works when a value is not present", function (assert) {
    assert.strictEqual(
      cacheBuster("/javascripts/my-script.js"),
      "/javascripts/my-script.js"
    );
    assert.strictEqual(
      cacheBuster("/javascripts/my-project/script.js"),
      "/javascripts/my-project/script.js"
    );
  });
});
