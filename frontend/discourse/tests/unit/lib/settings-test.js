import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { helperContext } from "discourse/lib/helpers";
import {
  emojiBasePath,
  prioritizeNameFallback,
  prioritizeNameInUx,
} from "discourse/lib/settings";

module("Unit | Lib | settings", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings = helperContext().siteSettings;
    this.siteSettings.enable_names = true;
    this.siteSettings.prioritize_username_in_ux = false;
    this.siteSettings.display_name_on_posts = true;
  });

  test("prioritizeNameInUx prefers a present name", function (assert) {
    assert.true(prioritizeNameInUx("Sam"), "a name is used");
  });

  test("prioritizeNameInUx ignores a blank name", function (assert) {
    assert.false(prioritizeNameInUx("   "), "a blank name is not used");
  });

  test("prioritizeNameInUx is off when usernames are prioritized", function (assert) {
    this.siteSettings.prioritize_username_in_ux = true;

    assert.false(prioritizeNameInUx("Sam"));
  });

  test("prioritizeNameInUx is off when names are disabled", function (assert) {
    this.siteSettings.enable_names = false;

    assert.false(prioritizeNameInUx("Sam"));
  });

  test("prioritizeNameFallback prefers the name when posts show names", function (assert) {
    assert.strictEqual(prioritizeNameFallback("Sam", "sam"), "Sam");
    assert.strictEqual(
      prioritizeNameFallback("", "sam"),
      "sam",
      "falls back to the username without a name"
    );
  });

  test("prioritizeNameFallback uses the username when posts hide names", function (assert) {
    this.siteSettings.display_name_on_posts = false;

    assert.strictEqual(prioritizeNameFallback("Sam", "sam"), "sam");
  });

  test("emojiBasePath uses the local path without an external URL", function (assert) {
    this.siteSettings.external_emoji_url = "";

    assert.strictEqual(emojiBasePath(), "/images/emoji");
  });

  test("emojiBasePath uses the external URL when set", function (assert) {
    this.siteSettings.external_emoji_url = "https://emoji.example";

    assert.strictEqual(emojiBasePath(), "https://emoji.example");
  });
});
