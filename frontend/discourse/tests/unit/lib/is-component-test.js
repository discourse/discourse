import { module, test } from "qunit";
import HeadingThumbnail from "discourse/blocks/thumbnails/heading";
import isComponent from "discourse/lib/is-component";
import DLightDarkImg from "discourse/ui-kit/d-light-dark-img";

module("Unit | lib | is-component", function () {
  test("returns true for a template-only component", function (assert) {
    assert.true(isComponent(HeadingThumbnail));
  });

  test("returns true for a class-backed component", function (assert) {
    assert.true(isComponent(DLightDarkImg));
  });

  test("returns false for nullish values", function (assert) {
    assert.false(isComponent(null));
    assert.false(isComponent(undefined));
  });

  test("returns false for primitives", function (assert) {
    assert.false(isComponent("/uploads/thumb.png"));
    assert.false(isComponent(123));
    assert.false(isComponent(true));
  });

  test("returns false for a plain object (including a { light, dark } pair)", function (assert) {
    assert.false(isComponent({}));
    assert.false(isComponent({ light: "/a.png", dark: "/b.png" }));
  });

  test("returns false for a plain function or class without a template", function (assert) {
    assert.false(isComponent(function () {}));
    assert.false(isComponent(class {}));
  });
});
