import { module, test } from "qunit";
import { handleRedditOneboxResizeMessage } from "discourse/instance-initializers/onebox-decorators";

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
    assert.strictEqual(iframe.getAttribute("scrolling"), "no");
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
});
