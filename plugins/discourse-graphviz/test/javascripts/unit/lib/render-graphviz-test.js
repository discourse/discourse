/* eslint-disable no-script-url */
import { module, test } from "qunit";
import { sanitizeGraphvizSvg } from "discourse/plugins/discourse-graphviz/discourse/lib/render-graphviz";

function sanitize(inner) {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">${inner}</svg>`;
  const doc = new DOMParser().parseFromString(svg, "image/svg+xml");
  return sanitizeGraphvizSvg(doc.documentElement).outerHTML;
}

module("Unit | Utility | render-graphviz | sanitize", function () {
  test("strips anchors with javascript: URLs", function (assert) {
    const result = sanitize(
      `<a xlink:href="javascript:alert(1)"><text>x</text></a>`
    );
    assert.false(result.includes("javascript:"), "removes javascript scheme");
    assert.true(result.includes("<text"), "keeps the inner content");
  });

  test("strips anchors case-insensitively", function (assert) {
    const result = sanitize(
      `<a xlink:href="JaVaScRiPt:alert(1)"><text>x</text></a>`
    );
    assert.false(/javascript:/i.test(result), "removes mixed-case javascript");
  });

  test("strips data:, vbscript:, file: and mailto: URLs", function (assert) {
    for (const scheme of [
      "data:text/html,alert(1)",
      "vbscript:alert(1)",
      "file:///etc/passwd",
      "mailto:test@example.com",
    ]) {
      const result = sanitize(`<a xlink:href="${scheme}"><text>x</text></a>`);
      assert.true(
        result.includes("<text"),
        `unwraps anchor but keeps content for ${scheme}`
      );
      assert.false(result.includes("<a"), `removes the anchor for ${scheme}`);
    }
  });

  test("preserves http and https URLs", function (assert) {
    for (const url of ["http://example.com", "https://example.com"]) {
      const result = sanitize(`<a xlink:href="${url}"><text>x</text></a>`);
      assert.true(result.includes(url), `keeps ${url}`);
      assert.true(result.includes("<a"), `keeps the anchor for ${url}`);
    }
  });

  test("preserves relative URLs", function (assert) {
    const result = sanitize(`<a xlink:href="/some/path"><text>x</text></a>`);
    assert.true(result.includes("/some/path"), "keeps relative path");
    assert.true(result.includes("<a"), "keeps the anchor");
  });

  test("removes script and foreignObject elements", function (assert) {
    const result = sanitize(
      `<script>alert(1)</script><foreignObject><div>x</div></foreignObject><text>ok</text>`
    );
    assert.false(result.includes("alert"), "removes script content");
    assert.false(result.includes("foreignObject"), "removes foreignObject");
    assert.true(result.includes("ok"), "keeps safe content");
  });

  test("strips on* event handler attributes", function (assert) {
    const result = sanitize(`<rect onclick="alert(1)" width="10"></rect>`);
    assert.false(result.includes("onclick"), "removes onclick attribute");
    assert.true(result.includes("width"), "keeps benign attributes");
  });
});
