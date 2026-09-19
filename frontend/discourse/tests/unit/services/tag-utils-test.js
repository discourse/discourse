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
      this.tagUtils.createContentFromInput("special!@chars"),
      "specialchars"
    );
  });

  test("createContentFromInput allows periods in the middle of tag names", function (assert) {
    assert.strictEqual(
      this.tagUtils.createContentFromInput("node.js"),
      "node.js"
    );
    assert.strictEqual(
      this.tagUtils.createContentFromInput(".node.js."),
      "node.js"
    );
  });

  test("sortSearchResults keeps usable tags before disabled ones when sorting alphabetically", function (assert) {
    this.tagUtils.siteSettings.tags_sort_alphabetically = true;

    const results = [
      { name: "z-ready", disabled: false },
      { name: "ready-to-deploy", disabled: true },
      { name: "apple-ready", disabled: false },
      { name: "boom-ready", disabled: true },
    ];

    assert.deepEqual(
      this.tagUtils.sortSearchResults(results).map((r) => r.name),
      ["apple-ready", "z-ready", "boom-ready", "ready-to-deploy"]
    );
  });
});
