import {
  iconHTML,
  iconNode,
  convertIconClass
} from "discourse-common/lib/icon-library";

QUnit.module("lib:icon-library");

QUnit.test("return icon markup", assert => {
  assert.ok(iconHTML("bars").indexOf('use xlink:href="#bars"') > -1);

  const nodeIcon = iconNode("bars");
  assert.equal(nodeIcon.tagName, "svg");
  assert.equal(
    nodeIcon.properties.attributes.class,
    "fa d-icon d-icon-bars svg-icon svg-node"
  );
});

QUnit.test("convert icon names", assert => {
  const fa5Icon = convertIconClass("fab fa-facebook");
  assert.ok(iconHTML(fa5Icon).indexOf("fab-facebook") > -1, "FA 5 syntax");

  const iconC = convertIconClass("  fab fa-facebook  ");
  assert.ok(iconHTML(iconC).indexOf("  ") === -1, "trims whitespace");
});
