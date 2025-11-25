import { module, test } from "qunit";
import {
  buildImageMarkdown,
  sanitizeAlt,
} from "discourse/lib/markdown-image-builder";

module("Unit | Lib | markdown-image-builder", function () {
  module("sanitizeAlt", function () {
    test("returns empty string by default for null or empty text", function (assert) {
      assert.strictEqual(sanitizeAlt(null), "");
      assert.strictEqual(sanitizeAlt(undefined), "");
      assert.strictEqual(sanitizeAlt(""), "");
      assert.strictEqual(sanitizeAlt("   "), "");
    });

    test("returns fallback for null or empty text when fallback is provided", function (assert) {
      assert.strictEqual(sanitizeAlt(null, { fallback: "image" }), "image");
      assert.strictEqual(
        sanitizeAlt(undefined, { fallback: "image" }),
        "image"
      );
      assert.strictEqual(sanitizeAlt("", { fallback: "image" }), "image");
      assert.strictEqual(sanitizeAlt("   ", { fallback: "image" }), "image");
    });

    test("escapes pipes for markdown", function (assert) {
      assert.strictEqual(
        sanitizeAlt("alt|text|with|pipes"),
        "alt&#124;text&#124;with&#124;pipes"
      );
    });

    test("escapes backslashes, brackets", function (assert) {
      assert.strictEqual(
        sanitizeAlt("text\\with\\slashes"),
        "text\\\\with\\\\slashes"
      );
      assert.strictEqual(
        sanitizeAlt("text[with]brackets"),
        "text\\[with\\]brackets"
      );
    });

    test("trims whitespace", function (assert) {
      assert.strictEqual(sanitizeAlt("  trimmed  "), "trimmed");
    });
  });

  module("buildImageMarkdown", function () {
    test("returns empty string when src is missing", function (assert) {
      assert.strictEqual(buildImageMarkdown({}), "");
      assert.strictEqual(buildImageMarkdown({ alt: "test" }), "");
    });

    test("builds basic image markdown", function (assert) {
      assert.strictEqual(
        buildImageMarkdown({ src: "/uploads/image.png" }),
        "![](/uploads/image.png)"
      );
    });

    test("builds basic image markdown with fallback alt", function (assert) {
      assert.strictEqual(
        buildImageMarkdown({ src: "/uploads/image.png", fallbackAlt: "image" }),
        "![image](/uploads/image.png)"
      );
    });

    test("includes alt text", function (assert) {
      assert.strictEqual(
        buildImageMarkdown({ src: "/uploads/image.png", alt: "My Image" }),
        "![My Image](/uploads/image.png)"
      );
    });

    test("includes dimensions when both width and height are provided", function (assert) {
      assert.strictEqual(
        buildImageMarkdown({
          src: "/uploads/image.png",
          alt: "test",
          width: 640,
          height: 480,
        }),
        "![test|640x480](/uploads/image.png)"
      );
    });

    test("omits dimensions when only width is provided", function (assert) {
      assert.strictEqual(
        buildImageMarkdown({
          src: "/uploads/image.png",
          alt: "test",
          width: 640,
        }),
        "![test](/uploads/image.png)"
      );
    });

    test("omits dimensions when only height is provided", function (assert) {
      assert.strictEqual(
        buildImageMarkdown({
          src: "/uploads/image.png",
          alt: "test",
          height: 480,
        }),
        "![test](/uploads/image.png)"
      );
    });

    test("includes title when provided", function (assert) {
      assert.strictEqual(
        buildImageMarkdown({
          src: "/uploads/image.png",
          alt: "test",
          title: "Image Title",
        }),
        '![test](/uploads/image.png "Image Title")'
      );
    });

    test("escapes pipe in dimensions for table context", function (assert) {
      assert.strictEqual(
        buildImageMarkdown({
          src: "/uploads/image.png",
          alt: "test",
          width: 640,
          height: 480,
          escapeTablePipe: true,
        }),
        "![test\\|640x480](/uploads/image.png)"
      );
    });

    test("sanitizes alt text", function (assert) {
      assert.strictEqual(
        buildImageMarkdown({
          src: "/uploads/image.png",
          alt: "text|with|pipes",
        }),
        "![text&#124;with&#124;pipes](/uploads/image.png)"
      );
    });

    test("builds complete markdown with all options", function (assert) {
      assert.strictEqual(
        buildImageMarkdown({
          src: "upload://secure.png",
          alt: "diagram",
          width: 800,
          height: 600,
          title: "Architecture Diagram",
        }),
        '![diagram|800x600](upload://secure.png "Architecture Diagram")'
      );
    });
  });
});
