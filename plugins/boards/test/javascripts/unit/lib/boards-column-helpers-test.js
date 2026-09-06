import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  columnColorVariable,
  hasColumnColor,
} from "discourse/plugins/boards/discourse/lib/boards-column-helpers";

module("Boards | Unit | Lib | boards-column-helpers", function (hooks) {
  setupTest(hooks);

  test("hasColumnColor recognizes valid hex values only", function (assert) {
    assert.true(hasColumnColor("1a2b3c"), "a 6-digit hex has a color");
    assert.true(hasColumnColor("f0a"), "a 3-digit hex has a color");
    assert.false(hasColumnColor(null), "no value has no color");
    assert.false(hasColumnColor(""), "empty has no color");
    assert.false(hasColumnColor("nope!"), "a malformed value has no color");
  });

  test("columnColorVariable emits the fill plus contrasting text colors", function (assert) {
    assert.strictEqual(
      columnColorVariable("1a2b3c").toString(),
      "--discourse-boards-column-color: #1a2b3c; --discourse-boards-column-title-text-color: #ffffff;",
      "a dark color gets white title text"
    );
    assert.strictEqual(
      columnColorVariable("ddb30e").toString(),
      "--discourse-boards-column-color: #ddb30e; --discourse-boards-column-title-text-color: #ffffff;",
      "a light color still gets light text on the darker title chip"
    );
    assert.strictEqual(
      columnColorVariable("f0a").toString(),
      "--discourse-boards-column-color: #ff00aa; --discourse-boards-column-title-text-color: #ffffff;",
      "short hexes are expanded"
    );
    assert.strictEqual(
      columnColorVariable(null).toString(),
      "--discourse-boards-column-color: var(--primary-500); --discourse-boards-column-title-text-color: var(--secondary);",
      "unset/invalid colors fall back to scheme variables for the fill and text"
    );
  });
});
