import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import SiteSettingMatcher from "admin/lib/site-setting-matcher";
import SiteSetting from "admin/models/site-setting";

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
});
