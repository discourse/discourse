import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import SiteSettingMatcher from "discourse/admin/lib/site-setting-matcher";
import SiteSetting from "discourse/admin/models/site-setting";

module("Unit | Lib | SiteSettingMatcher", function (hooks) {
  setupTest(hooks);

  const shortTitle = SiteSetting.create({
    setting: "short_title",
    description:
      "The short title will be used on the user's home screen, launcher, or other places where space may be limited.",
    keywords: ["intro"],
    value: "Heckers",
  });

  test("#isNameMatch", function (assert) {
    const matchingMatcher = new SiteSettingMatcher("sho", shortTitle);

    assert.true(matchingMatcher.isNameMatch);

    const nonMatchingMatcher = new SiteSettingMatcher("foo", shortTitle);

    assert.false(nonMatchingMatcher.isNameMatch);
  });

  test("#isKeywordMatch", function (assert) {
    const matchingMatcher = new SiteSettingMatcher("intro", shortTitle);

    assert.true(matchingMatcher.isKeywordMatch);

    const nonMatchingMatcher = new SiteSettingMatcher("foo", shortTitle);

    assert.false(nonMatchingMatcher.isKeywordMatch);
  });

  test("#isDescriptionMatch", function (assert) {
    const matchingMatcher = new SiteSettingMatcher("launcher", shortTitle);

    assert.true(matchingMatcher.isDescriptionMatch);

    const nonMatchingMatcher = new SiteSettingMatcher("foo", shortTitle);

    assert.false(nonMatchingMatcher.isDescriptionMatch);
  });

  test("#isValueMatch", function (assert) {
    const matchingMatcher = new SiteSettingMatcher("heckers", shortTitle);

    assert.true(matchingMatcher.isValueMatch);

    const nonMatchingMatcher = new SiteSettingMatcher("foo", shortTitle);

    assert.false(nonMatchingMatcher.isValueMatch);
  });

  test("#isFuzzyNameMatch", function (assert) {
    const tooShortMatcher = new SiteSettingMatcher("so", shortTitle);

    assert.false(tooShortMatcher.isFuzzyNameMatch);

    const nonMatchingMatcher = new SiteSettingMatcher("foo", shortTitle);

    assert.false(nonMatchingMatcher.isFuzzyNameMatch);

    const matchingMatcher = new SiteSettingMatcher("s tle", shortTitle);

    assert.true(matchingMatcher.isFuzzyNameMatch);
    assert.strictEqual(matchingMatcher.matchStrength, -1); // Smallest number of gaps.
  });

  module("OR filter (| separator)", function () {
    test("#isNameMatch returns true if any term matches", function (assert) {
      assert.true(
        new SiteSettingMatcher("short_title|foo", shortTitle).isNameMatch
      );
      assert.true(
        new SiteSettingMatcher("foo|short_title", shortTitle).isNameMatch
      );
      assert.false(new SiteSettingMatcher("foo|bar", shortTitle).isNameMatch);
    });

    test("#isKeywordMatch returns true if any term matches a keyword", function (assert) {
      assert.true(
        new SiteSettingMatcher("intro|foo", shortTitle).isKeywordMatch
      );
      assert.false(
        new SiteSettingMatcher("foo|bar", shortTitle).isKeywordMatch
      );
    });

    test("#isDescriptionMatch returns true if any term matches the description", function (assert) {
      assert.true(
        new SiteSettingMatcher("launcher|foo", shortTitle).isDescriptionMatch
      );
      assert.false(
        new SiteSettingMatcher("foo|bar", shortTitle).isDescriptionMatch
      );
    });

    test("#isValueMatch returns true if any term matches the value", function (assert) {
      assert.true(
        new SiteSettingMatcher("heckers|foo", shortTitle).isValueMatch
      );
      assert.false(new SiteSettingMatcher("foo|bar", shortTitle).isValueMatch);
    });

    test("#isFuzzyNameMatch always returns false in OR mode", function (assert) {
      assert.false(
        new SiteSettingMatcher("s tle|foo", shortTitle).isFuzzyNameMatch
      );
    });
  });
});
