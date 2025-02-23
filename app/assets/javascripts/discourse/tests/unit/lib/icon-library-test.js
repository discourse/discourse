import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { withSilencedDeprecations } from "discourse/lib/deprecated";
import {
  convertIconClass,
  iconHTML,
  iconNode,
} from "discourse/lib/icon-library";
import {
  disableRaiseOnDeprecation,
  enableRaiseOnDeprecation,
} from "discourse/tests/helpers/raise-on-deprecation";

module("Unit | Utility | icon-library", function (hooks) {
  setupTest(hooks);

  test("return icon markup", function (assert) {
    assert.true(iconHTML("bars").includes('use href="#bars"'));

    const nodeIcon = iconNode("bars");
    assert.strictEqual(nodeIcon.tagName, "svg");
    assert.strictEqual(
      nodeIcon.properties.attributes.class,
      "fa d-icon d-icon-bars svg-icon svg-node"
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

  test("fa5 remaps throws error", function (assert) {
    disableRaiseOnDeprecation();
    assert.throws(
      () => {
        iconHTML("adjust");
      },
      /Deprecation notice: The icon name "adjust" has been updated to "circle-half-stroke".*\[deprecation id: discourse\.fontawesome-6-upgrade\]/,
      "throws an error if icon name is deprecated"
    );

    assert.throws(
      () => {
        iconHTML("far-dot-circle");
      },
      /Deprecation notice: The icon name "far-dot-circle" has been updated to "far-circle-dot".*\[deprecation id: discourse\.fontawesome-6-upgrade\]/,
      "throws an error if icon name is deprecated"
    );
    enableRaiseOnDeprecation();
  });
});
