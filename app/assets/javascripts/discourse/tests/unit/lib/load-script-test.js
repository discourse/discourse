import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { cacheBuster } from "discourse/lib/load-script";
import { PUBLIC_JS_VERSIONS as jsVersions } from "discourse/lib/public-js-versions";

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

  test("generates URLs with version number in the query params", function (assert) {
    assert.strictEqual(
      cacheBuster("/javascripts/pikaday.js"),
      `/javascripts/${jsVersions["pikaday.js"]}`
    );
    assert.strictEqual(
      cacheBuster("/javascripts/ace/ace.js"),
      `/javascripts/${jsVersions["ace/ace.js"]}`
    );
  });

  test("lookups are case-insensitive", (assert) => {
    assert.strictEqual(
      cacheBuster("/javascripts/Chart.min.js"),
      `/javascripts/${jsVersions["chart.min.js"]}`
    );
    assert.strictEqual(
      cacheBuster("/javascripts/chart.min.js"),
      `/javascripts/${jsVersions["chart.min.js"]}`
    );
  });
});
