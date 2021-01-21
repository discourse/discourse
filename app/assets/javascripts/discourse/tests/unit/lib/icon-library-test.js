import {
  convertIconClass,
  iconHTML,
  iconNode,
} from "discourse-common/lib/icon-library";
import { module, test } from "qunit";

module("Unit | Utility | icon-library", function () {
  test("return icon markup", function (assert) {
    assert.ok(iconHTML("bars").indexOf('use xlink:href="#bars"') > -1);

    const nodeIcon = iconNode("bars");
    assert.equal(nodeIcon.tagName, "svg");
    assert.equal(
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
});
