import LinkLookup from "discourse/lib/link-lookup";
import { module, test } from "qunit";
import { getOwner } from "discourse-common/lib/get-owner";

module("Unit | Utility | link-lookup", function (hooks) {
  hooks.beforeEach(function () {
    const store = getOwner(this).lookup("service:store");
    this.post = store.createRecord("post");
    this.linkLookup = new LinkLookup({
      "en.wikipedia.org/wiki/handheld_game_console": {
        post_number: 1,
      },
    });
  });

  test("works with https", function (assert) {
    assert.ok(
      this.linkLookup.check(
        this.post,
        "https://en.wikipedia.org/wiki/handheld_game_console"
      )[0]
    );
  });

  test("works with http", function (assert) {
    assert.ok(
      this.linkLookup.check(
        this.post,
        "http://en.wikipedia.org/wiki/handheld_game_console"
      )[0]
    );
  });

  test("works with trailing slash", function (assert) {
    assert.ok(
      this.linkLookup.check(
        this.post,
        "https://en.wikipedia.org/wiki/handheld_game_console/"
      )[0]
    );
  });

  test("works with uppercase characters", function (assert) {
    assert.ok(
      this.linkLookup.check(
        this.post,
        "https://en.wikipedia.org/wiki/Handheld_game_console"
      )[0]
    );
  });
});
