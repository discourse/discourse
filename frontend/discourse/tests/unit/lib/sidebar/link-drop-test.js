import { module, test } from "qunit";
import { extractDroppedWebLink } from "discourse/lib/sidebar/link-drop";

/**
 * Stands in for the decorated payload a drop target hands its consumer. Each
 * accessor is stated outright rather than derived from the others, so a test
 * says exactly what the browser put on the drag and cannot accidentally assert
 * against a reimplementation of the library that normally parses it.
 */
function externalSource({ urls = [], html = null, text = null, strings = {} }) {
  return {
    getURLs: () => urls,
    getHTML: () => html,
    getText: () => text,
    getStringData: (mediaType) => strings[mediaType] ?? null,
  };
}

module("Unit | Lib | Sidebar | link-drop", function () {
  test("takes the first URL it can actually use", function (assert) {
    const link = extractDroppedWebLink(
      externalSource({
        urls: [
          "not a URL",
          "https://example.com/first",
          "https://example.com/second",
        ],
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
      "entries that are not usable URLs are passed over rather than failing the drop"
    );
  });

  test("uses dragged link text as the default name", function (assert) {
    const link = extractDroppedWebLink(
      externalSource({
        urls: ["https://example.com/article"],
        html: '<a href="https://example.com/article">  Example   article </a>',
        strings: { "text/uri-list": "https://example.com/article" },
      })
    );

    assert.strictEqual(
      link.name,
      "Example article",
      "HTML link text is normalized"
    );
  });

  test("keeps the title Firefox supplies alongside its own URL format", function (assert) {
    const link = extractDroppedWebLink(
      externalSource({
        urls: ["https://example.com/firefox"],
        strings: {
          "text/x-moz-url": "https://example.com/firefox\nFirefox title",
        },
      })
    );

    assert.strictEqual(
      link.name,
      "Firefox title",
      "the title is read back out of the format the URL came from"
    );
  });

  test("ignores Firefox titles when the URLs came from the standard type", function (assert) {
    const link = extractDroppedWebLink(
      externalSource({
        urls: ["https://example.com/standard"],
        strings: {
          "text/uri-list": "https://example.com/standard",
          "text/x-moz-url": "https://example.com/other\nA different page",
        },
      })
    );

    assert.strictEqual(
      link.name,
      "example.com",
      "a title is only trusted to name the URL it was sent beside"
    );
  });

  test("falls back to plain text, named after its host", function (assert) {
    const link = extractDroppedWebLink(
      externalSource({ text: "https://www.example.org/plain" })
    );

    assert.strictEqual(
      link.name,
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
        extractDroppedWebLink(externalSource({ text: value })),
        undefined,
        `${value} is rejected`
      );
    }

    assert.strictEqual(
      extractDroppedWebLink(externalSource({ text: "http://example.com" }))
        .value,
      "http://example.com/",
      "HTTP URLs are accepted"
    );
  });

  test("stores a link to this very site as a path", function (assert) {
    const link = extractDroppedWebLink(
      externalSource({
        urls: [`${window.location.origin}/t/a-topic/12?u=someone#post-3`],
        html: `<a href="${window.location.origin}/t/a-topic/12">A topic</a>`,
      })
    );

    assert.strictEqual(
      link.value,
      "/t/a-topic/12?u=someone#post-3",
      "the hostname is dropped so the link survives the site moving, and the query and fragment are kept because they are part of where it points"
    );
  });

  test("leaves a link to somewhere else absolute", function (assert) {
    const link = extractDroppedWebLink(
      externalSource({ urls: ["https://example.com/t/a-topic/12"] })
    );

    assert.strictEqual(
      link.value,
      "https://example.com/t/a-topic/12",
      "another site's URL is not ours to shorten"
    );
  });
});
