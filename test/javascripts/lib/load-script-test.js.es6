import loadScript from "discourse/lib/load-script";

QUnit.module("lib:load-script");

QUnit.test(
  "load with a script tag, and callbacks are only executed after script is loaded",
  async assert => {
    const src = "/javascripts/ace/ace.js";

    await loadScript(src).then(() => {
      assert.ok(
        typeof ace !== "undefined",
        "callbacks should only be executed after the script has fully loaded"
      );

      // cannot use the `find` test helper here because the script tag is injected outside of the test sandbox frame
      const scriptTags = Array.from(document.getElementsByTagName("script"));
      assert.ok(
        scriptTags.some(scriptTag => scriptTag.src.includes(src)),
        "the script should be loaded with a script tag"
      );
    });
  }
);
