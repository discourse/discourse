import { module, test } from "qunit";
import PhraseMatcher from "discourse/plugins/discourse-workflows/discourse/lib/phrase-matcher";

module("Discourse Workflows | Unit | Lib | phrase matcher", function () {
  test("matches patterns ignoring case, skipping ones that don't compile", async function (assert) {
    const matcher = new PhraseMatcher();

    try {
      const matched = await matcher.match("Some MAGIC WORDS", [
        "(magic words)",
        "(food stand)",
        "(?<name>bad",
      ]);

      assert.deepEqual([...matched], ["(magic words)"]);
    } finally {
      matcher.destroy();
    }
  });

  test("a pattern that keeps running too long is skipped from then on", async function (assert) {
    const matcher = new PhraseMatcher({ timeoutMs: 100 });
    const backtracking = "^(a+)+$";
    const slowText = `${"a".repeat(40)}! food stand`;

    try {
      const matched = await matcher.match(slowText, [
        backtracking,
        "(food stand)",
      ]);
      assert.deepEqual(
        [...matched],
        ["(food stand)"],
        "the other patterns still match"
      );

      const once = await matcher.match("aaaa", [backtracking]);
      assert.deepEqual([...once], [backtracking], "one timeout is forgiven");

      await matcher.match(slowText, [backtracking]);
      const twice = await matcher.match("aaaa", [backtracking]);
      assert.deepEqual([...twice], [], "a second timeout skips it");
    } finally {
      matcher.destroy();
    }
  });

  test("overlapping matches each get their own answer", async function (assert) {
    const matcher = new PhraseMatcher();

    try {
      const [first, second] = await Promise.all([
        matcher.match("Magic words", ["(magic words)", "(food stand)"]),
        matcher.match("food stand", ["(magic words)", "(food stand)"]),
      ]);

      assert.deepEqual([...first], ["(magic words)"]);
      assert.deepEqual([...second], ["(food stand)"]);
    } finally {
      matcher.destroy();
    }
  });
});
