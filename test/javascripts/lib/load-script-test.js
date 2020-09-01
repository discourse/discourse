import {
  loadScript,
  setupPublicJsHash,
  addHashToURL
} from "discourse/lib/load-script";

QUnit.module("lib:load-script");

QUnit.skip(
  "load with a script tag, and callbacks are only executed after script is loaded",
  async assert => {
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

QUnit.test("works when a hash is not present", async assert => {
  setupPublicJsHash(undefined);
  assert.equal(
    addHashToURL("/javascripts/pikaday.js"),
    "/javascripts/pikaday.js"
  );
  assert.equal(
    addHashToURL("/javascripts/ace/ace.js"),
    "/javascripts/ace/ace.js"
  );
});

QUnit.test("generates URLs with a hash", async assert => {
  setupPublicJsHash("abc123");
  assert.equal(
    addHashToURL("/javascripts/pikaday.js"),
    "/javascripts/pikaday-abc123.js"
  );
  assert.equal(
    addHashToURL("/javascripts/ace/ace.js"),
    "/javascripts/ace-abc123/ace.js"
  );
});
