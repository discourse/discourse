import { module, test } from "qunit";
import { isSameLocale } from "discourse/lib/locale-normalizer";

module("Unit | lib | locale-normalizer", function () {
  test("isSameLocale matches identical locales", function (assert) {
    assert.true(isSameLocale("en", "en"));
    assert.true(isSameLocale("zh_CN", "zh_CN"));
  });

  test("isSameLocale ignores region and separator/case differences", function (assert) {
    assert.true(isSameLocale("en_GB", "en"));
    assert.true(isSameLocale("en", "en_GB"));
    assert.true(isSameLocale("zh-TW", "zh_CN"));
    assert.true(isSameLocale("EN", "en"));
  });

  test("isSameLocale distinguishes different base languages", function (assert) {
    assert.false(isSameLocale("en", "hu"));
    assert.false(isSameLocale("pt", "es"));
  });

  test("isSameLocale is false when either locale is blank", function (assert) {
    assert.false(isSameLocale("en", null));
    assert.false(isSameLocale(undefined, "en"));
    assert.false(isSameLocale("", "en"));
  });
});
