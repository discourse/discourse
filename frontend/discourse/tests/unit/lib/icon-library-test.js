import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  convertIconClass,
  iconElement,
  iconHTML,
} from "discourse/lib/icon-library";

module("Unit | Utility | icon-library", function (hooks) {
  setupTest(hooks);

  test("creates icon element", function (assert) {
    const icon = iconElement("bars");
    assert.strictEqual(icon.tagName, "svg");
    assert.strictEqual(
      icon.className.baseVal,
      "fa d-icon d-icon-bars svg-icon fa-width-auto svg-node"
    );
  });

  test("convert icon names", function (assert) {
    const faIcon = convertIconClass("fab fa-facebook");
    assert.true(iconHTML(faIcon).includes("fab-facebook"), "FA syntax");

    const iconC = convertIconClass("  fab fa-facebook  ");
    assert.false(iconHTML(iconC).includes("  "), "trims whitespace");
  });

  test("escape icon names, classes, titles and aria-label", function (assert) {
    let html = iconHTML("'<img src='x'>", {
      translatedTitle: "'<script src='y'>",
      label: "<iframe src='z'>",
      class: "'<link href='w'>",
      "aria-label": "<script>alert(1)",
    });
    assert.true(html.includes("&#x27;&lt;img src=&#x27;x&#x27;&gt;"));
    assert.true(html.includes("&#x27;&lt;script src=&#x27;y&#x27;&gt;"));
    assert.true(html.includes("&lt;iframe src=&#x27;z&#x27;&gt;"));
    assert.true(html.includes("&#x27;&lt;link href=&#x27;w&#x27;&gt;"));

    html = iconHTML("'<img src='x'>", {
      "aria-label": "<script>alert(1)",
    });
    assert.true(html.includes("aria-label='&lt;script&gt;alert(1)'"));
  });
});
