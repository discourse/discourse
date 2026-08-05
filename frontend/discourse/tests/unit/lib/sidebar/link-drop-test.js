import { module, test } from "qunit";
import {
  extractDroppedWebLink,
  isExplicitWebLinkDrag,
  isWebLinkDrag,
} from "discourse/lib/sidebar/link-drop";

function dataTransfer(data = {}, types = Object.keys(data)) {
  return {
    types,
    getData(type) {
      return data[type] || "";
    },
  };
}

module("Unit | Lib | Sidebar | link-drop", function () {
  test("recognizes supported link drag types but not files", function (assert) {
    assert.true(
      isWebLinkDrag(dataTransfer({}, ["text/uri-list"])),
      "URI lists are recognized"
    );
    assert.true(
      isWebLinkDrag(dataTransfer({}, ["text/html", "text/plain"])),
      "HTML links are recognized"
    );
    assert.false(
      isWebLinkDrag(dataTransfer({}, ["Files", "text/uri-list"])),
      "file drags are excluded"
    );
    assert.false(
      isWebLinkDrag(dataTransfer({}, ["application/json"])),
      "unrelated data is excluded"
    );
  });

  test("distinguishes explicit link types from ambiguous text", function (assert) {
    assert.true(
      isExplicitWebLinkDrag(dataTransfer({}, ["text/uri-list"])),
      "URI lists provide an explicit link affordance"
    );
    assert.false(
      isExplicitWebLinkDrag(dataTransfer({}, ["text/html", "text/plain"])),
      "selected text does not provide an explicit link affordance"
    );
    assert.false(
      isExplicitWebLinkDrag(dataTransfer({}, ["Files", "text/uri-list"])),
      "file drags are excluded"
    );
  });

  test("extracts the first valid URL from a URI list", function (assert) {
    const link = extractDroppedWebLink(
      dataTransfer({
        "text/uri-list":
          "# A useful link\r\nnot a URL\r\nhttps://example.com/first\r\nhttps://example.com/second",
      })
    );

    assert.deepEqual(
      link,
      {
        icon: "link",
        name: "example.com",
        value: "https://example.com/first",
        segment: "primary",
      },
      "the first non-comment URL is used"
    );
  });

  test("uses dragged link text as the default name", function (assert) {
    const link = extractDroppedWebLink(
      dataTransfer({
        "text/uri-list": "https://example.com/article",
        "text/html":
          '<a href="https://example.com/article">  Example   article </a>',
      })
    );

    assert.strictEqual(
      link.name,
      "Example article",
      "HTML link text is normalized"
    );
  });

  test("supports Firefox link data and plain URL fallback", function (assert) {
    const firefoxLink = extractDroppedWebLink(
      dataTransfer({
        "text/x-moz-url": "https://example.com/firefox\nFirefox title",
      })
    );
    const plainLink = extractDroppedWebLink(
      dataTransfer({ "text/plain": "https://www.example.org/plain" })
    );

    assert.strictEqual(
      firefoxLink.name,
      "Firefox title",
      "Firefox's supplied title is used"
    );
    assert.strictEqual(
      plainLink.name,
      "example.org",
      "the hostname is used for a plain URL"
    );
  });

  test("accepts only absolute HTTP and HTTPS URLs", function (assert) {
    for (const value of [
      // eslint-disable-next-line no-script-url
      "javascript:alert(1)",
      "data:text/html,hello",
      "mailto:user@example.com",
      "/relative/path",
      "selected text",
    ]) {
      assert.strictEqual(
        extractDroppedWebLink(dataTransfer({ "text/plain": value })),
        undefined,
        `${value} is rejected`
      );
    }

    assert.strictEqual(
      extractDroppedWebLink(
        dataTransfer({ "text/plain": "http://example.com" })
      ).value,
      "http://example.com/",
      "HTTP URLs are accepted"
    );
  });
});
