import loadScript from "discourse/lib/load-script";

QUnit.module("lib:load-script");

QUnit.skip(
  "load with a script tag, and callbacks are only executed after script is loaded",
  async assert => {
    assert.ok(
      typeof window.ace === "undefined",
      "ensures ace is not previously loaded"
    );

    const src = "/javascripts/ace/ace.js";

    await loadScript(src).then(() => {
      assert.ok(
        typeof window.ace !== "undefined",
        "callbacks should only be executed after the script has fully loaded"
      );
    });
  }
);
