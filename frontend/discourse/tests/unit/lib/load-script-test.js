import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import loadScript from "discourse/lib/load-script";

module("Unit | Utility | load-script", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.originalCreateElement = document.createElement.bind(document);
    this.appendedScripts = [];
    this.mockScriptBehavior = null;

    const testContext = this;
    document.createElement = function (tagName) {
      const element = testContext.originalCreateElement(tagName);
      if (tagName.toLowerCase() === "script") {
        testContext.appendedScripts.push(element);
        const originalAppendChild = document.head.appendChild.bind(
          document.head
        );
        document.head.appendChild = function (child) {
          if (child === element && testContext.mockScriptBehavior) {
            setTimeout(() => {
              testContext.mockScriptBehavior(element);
            }, 0);
            return child;
          }
          return originalAppendChild(child);
        };
      }
      return element;
    };
  });

  hooks.afterEach(function () {
    document.createElement = this.originalCreateElement;
    this.appendedScripts.forEach((script) => script.remove?.());
  });

  test("loadScript rejects when script fails to load", async function (assert) {
    this.mockScriptBehavior = (script) => {
      script.onerror?.();
    };

    try {
      await loadScript("/test-scripts/nonexistent-" + Date.now() + ".js");
      assert.false(true, "should have rejected");
    } catch (error) {
      assert.true(
        error.message.includes("Failed to load"),
        "rejects with appropriate error message"
      );
    }
  });

  test("loadScript can retry after previous failure", async function (assert) {
    const uniqueUrl = "/test-scripts/retry-test-" + Date.now() + ".js";
    let callCount = 0;

    this.mockScriptBehavior = (script) => {
      callCount++;
      if (callCount === 1) {
        script.onerror?.();
      } else {
        script.onload?.();
      }
    };

    try {
      await loadScript(uniqueUrl);
      assert.false(true, "first call should have rejected");
    } catch {
      assert.strictEqual(callCount, 1, "first attempt was made");
    }

    await loadScript(uniqueUrl);
    assert.strictEqual(callCount, 2, "second attempt was made after failure");
  });
});
