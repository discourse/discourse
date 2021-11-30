import {
  convertIconClass,
  iconHTML,
  iconNode,
} from "discourse-common/lib/icon-library";
import { module, test } from "qunit";

module("Unit | Utility | icon-library", function () {
  test("return icon markup", function (assert) {
    assert.ok(iconHTML("bars").indexOf('use href="#bars"') > -1);

    const nodeIcon = iconNode("bars");
    assert.strictEqual(nodeIcon.tagName, "svg");
    assert.strictEqual(
      nodeIcon.properties.attributes.class,
      "fa d-icon d-icon-bars svg-icon svg-node"
    );
  });

  test("convert icon names", function (assert) {
    const fa5Icon = convertIconClass("fab fa-facebook");
    assert.ok(iconHTML(fa5Icon).indexOf("fab-facebook") > -1, "FA 5 syntax");

    const iconC = convertIconClass("  fab fa-facebook  ");
    assert.ok(iconHTML(iconC).indexOf("  ") === -1, "trims whitespace");
  });

  test("escape icon names, classes and titles", function (assert) {
    const html = iconHTML("'<img src='x'>", {
      translatedtitle: "'<script src='y'>",
      label: "<iframe src='z'>",
      class: "'<link href='w'>",
    });
    assert.ok(html.includes("&#x27;&lt;img src=&#x27;x&#x27;&gt;"));
    assert.ok(html.includes("&#x27;&lt;script src=&#x27;y&#x27;&gt;"));
    assert.ok(html.includes("&lt;iframe src=&#x27;z&#x27;&gt;"));
    assert.ok(html.includes("&#x27;&lt;link href=&#x27;w&#x27;&gt;"));
  });
});
