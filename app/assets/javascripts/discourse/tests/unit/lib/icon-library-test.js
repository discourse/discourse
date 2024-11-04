import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { withSilencedDeprecations } from "discourse-common/lib/deprecated";
import {
  convertIconClass,
  iconHTML,
  iconNode,
} from "discourse-common/lib/icon-library";

module("Unit | Utility | icon-library", function (hooks) {
  setupTest(hooks);

  test("return icon markup", function (assert) {
    assert.ok(iconHTML("bars").includes('use href="#bars"'));

    const nodeIcon = iconNode("bars");
    assert.strictEqual(nodeIcon.tagName, "svg");
    assert.strictEqual(
      nodeIcon.properties.attributes.class,
      "fa d-icon d-icon-bars svg-icon svg-node"
    );
  });

  test("convert icon names", function (assert) {
    const faIcon = convertIconClass("fab fa-facebook");
    assert.ok(iconHTML(faIcon).includes("fab-facebook"), "FA syntax");

    const iconC = convertIconClass("  fab fa-facebook  ");
    assert.ok(!iconHTML(iconC).includes("  "), "trims whitespace");
  });

  test("escape icon names, classes, titles and aria-label", function (assert) {
    let html = iconHTML("'<img src='x'>", {
      translatedTitle: "'<script src='y'>",
      label: "<iframe src='z'>",
      class: "'<link href='w'>",
      "aria-label": "<script>alert(1)",
    });
    assert.ok(html.includes("&#x27;&lt;img src=&#x27;x&#x27;&gt;"));
    assert.ok(html.includes("&#x27;&lt;script src=&#x27;y&#x27;&gt;"));
    assert.ok(html.includes("&lt;iframe src=&#x27;z&#x27;&gt;"));
    assert.ok(html.includes("&#x27;&lt;link href=&#x27;w&#x27;&gt;"));

    html = iconHTML("'<img src='x'>", {
      "aria-label": "<script>alert(1)",
    });
    assert.ok(html.includes("aria-label='&lt;script&gt;alert(1)'"));
  });

  test("fa5 remaps", function (assert) {
    withSilencedDeprecations("discourse.fontawesome-6-upgrade", () => {
      const adjustIcon = iconHTML("adjust");
      assert.true(adjustIcon.includes("d-icon-adjust"), "class is maintained");
      assert.true(
        adjustIcon.includes('href="#circle-half-stroke"'),
        "has remapped icon"
      );

      const farIcon = iconHTML("far-dot-circle");
      assert.true(
        farIcon.includes("d-icon-far-dot-circle"),
        "class is maintained"
      );
      assert.true(
        farIcon.includes('href="#far-circle-dot"'),
        "has remapped icon"
      );
    });
  });
});
