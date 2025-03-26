import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import {
  convertIconClass,
  iconHTML,
  iconNode,
  isTesting,
} from "discourse/lib/icon-library";

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
    const stub = sinon.stub(isTesting);
    stub.returns(false);

    try {
      const adjustIcon = iconHTML("adjust");
      assert.true(adjustIcon.includes("d-icon-adjust"), "class is maintained");
      assert.true(adjustIcon.includes('href="#adjust"'), "keeps original icon");

      const farIcon = iconHTML("far-dot-circle");
      assert.true(
        farIcon.includes("d-icon-far-dot-circle"),
        "class is maintained"
      );
      assert.true(
        farIcon.includes('href="#far-dot-circle"'),
        "keeps original icon"
      );
    } finally {
      stub.restore();
    }
  });

  test("fa remaps throws error", function (assert) {
    assert.throws(
      () => {
        iconHTML("adjust");
      },
      `Missing icon error: The icon name "adjust" has been removed and should be updated to "circle-half-stroke" in your code. More info at https://meta.discourse.org/t/325349.`,
      "throws an error if icon name is deprecated"
    );

    assert.throws(
      () => {
        iconHTML("far-dot-circle");
      },
      `Missing icon error: The icon name "far-dot-circle" has been removed and should be updated to "far-circle-dot" in your code. More info at https://meta.discourse.org/t/325349.`,
      "throws an error if icon name is deprecated"
    );
  });
});
