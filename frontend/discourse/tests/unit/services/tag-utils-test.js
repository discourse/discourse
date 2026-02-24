import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

module("Unit | Service | tag-utils", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.tagUtils = getOwner(this).lookup("service:tag-utils");
  });

  test("createContentFromInput squeezes consecutive dashes", function (assert) {
    assert.strictEqual(
      this.tagUtils.createContentFromInput("test--tag"),
      "test-tag"
    );
    assert.strictEqual(
      this.tagUtils.createContentFromInput("multi---dash"),
      "multi-dash"
    );
    assert.strictEqual(
      this.tagUtils.createContentFromInput("a--b--c"),
      "a-b-c"
    );
  });

  test("createContentFromInput handles basic normalization", function (assert) {
    assert.strictEqual(
      this.tagUtils.createContentFromInput("  spaced  "),
      "spaced"
    );
    assert.strictEqual(
      this.tagUtils.createContentFromInput("has spaces"),
      "has-spaces"
    );
    assert.strictEqual(
      this.tagUtils.createContentFromInput("special!@#chars"),
      "specialchars"
    );
  });
});
