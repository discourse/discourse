import { module, test } from "qunit";
import {
  decorateRedditOneboxes,
  handleRedditOneboxResizeMessage,
} from "discourse/instance-initializers/onebox-decorators";

module("Unit | Instance Initializer | onebox-decorators", function () {
  test("handleRedditOneboxResizeMessage resizes the matching reddit iframe", function (assert) {
    const root = document.createElement("div");
    const iframe = document.createElement("iframe");
    const source = {};

    iframe.className = "reddit-onebox";
    iframe.setAttribute("height", "500");
    Object.defineProperty(iframe, "contentWindow", {
      configurable: true,
      value: source,
    });
    root.appendChild(iframe);

    handleRedditOneboxResizeMessage(
      {
        origin: "https://embed.reddit.com",
        source,
        data: JSON.stringify({ type: "resize.embed", data: 321 }),
      },
      root
    );

    assert.strictEqual(iframe.getAttribute("height"), "321");
  });

  test("handleRedditOneboxResizeMessage ignores unrelated messages", function (assert) {
    const root = document.createElement("div");
    const iframe = document.createElement("iframe");
    const source = {};

    iframe.className = "reddit-onebox";
    iframe.setAttribute("height", "500");
    Object.defineProperty(iframe, "contentWindow", {
      configurable: true,
      value: source,
    });
    root.appendChild(iframe);

    handleRedditOneboxResizeMessage(
      {
        origin: "https://example.com",
        source,
        data: JSON.stringify({ type: "resize.embed", data: 321 }),
      },
      root
    );

    assert.strictEqual(iframe.getAttribute("height"), "500");
  });

  test("decorateRedditOneboxes adds a single global listener and cleans it up", function (assert) {
    const makeRoot = () => {
      const root = document.createElement("div");
      const iframe = document.createElement("iframe");
      iframe.className = "reddit-onebox";
      root.appendChild(iframe);
      return root;
    };

    const eventTarget = {
      addCalls: 0,
      removeCalls: 0,
      addEventListener() {
        this.addCalls += 1;
      },
      removeEventListener() {
        this.removeCalls += 1;
      },
    };

    const cleanupOne = decorateRedditOneboxes(makeRoot(), eventTarget);
    const cleanupTwo = decorateRedditOneboxes(makeRoot(), eventTarget);

    assert.strictEqual(eventTarget.addCalls, 1);

    cleanupOne();
    assert.strictEqual(eventTarget.removeCalls, 0);

    cleanupTwo();
    assert.strictEqual(eventTarget.removeCalls, 1);
  });

  test("decorateRedditOneboxes does nothing without a reddit iframe", function (assert) {
    const root = document.createElement("div");
    const eventTarget = {
      addEventListener() {
        assert.step("addEventListener");
      },
    };

    const cleanup = decorateRedditOneboxes(root, eventTarget);

    assert.strictEqual(cleanup, undefined);
    assert.verifySteps([]);
  });
});
