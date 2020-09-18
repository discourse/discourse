import { loadScript, cacheBuster } from "discourse/lib/load-script";
import { PUBLIC_JS_VERSIONS as jsVersions } from "discourse/lib/public-js-versions";

QUnit.module("lib:load-script");

QUnit.skip(
  "load with a script tag, and callbacks are only executed after script is loaded",
  async (assert) => {
    assert.ok(
      typeof window.ace === "undefined",
      "ensures ace is not previously loaded"
    );

    const src = "/javascripts/ace/ace.js";

    await loadScript(src);
    assert.ok(
      typeof window.ace !== "undefined",
      "callbacks should only be executed after the script has fully loaded"
    );
  }
);

QUnit.test("works when a value is not present", (assert) => {
  assert.equal(
    cacheBuster("/javascripts/my-script.js"),
    "/javascripts/my-script.js"
  );
  assert.equal(
    cacheBuster("/javascripts/my-project/script.js"),
    "/javascripts/my-project/script.js"
  );
});

QUnit.test(
  "generates URLs with version number in the query params",
  (assert) => {
    assert.equal(
      cacheBuster("/javascripts/pikaday.js"),
      `/javascripts/${jsVersions["pikaday.js"]}`
    );
    assert.equal(
      cacheBuster("/javascripts/ace/ace.js"),
      `/javascripts/${jsVersions["ace/ace.js"]}`
    );
  }
);
