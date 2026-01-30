import { module, test } from "qunit";
import {
  findClosestMatch,
  formatWithSuggestion,
  levenshteinDistance,
} from "discourse/lib/string-similarity";

module("Unit | Lib | string-similarity", function () {
  module("levenshteinDistance", function () {
    test("returns 0 for identical strings", function (assert) {
      assert.strictEqual(levenshteinDistance("hello", "hello"), 0);
      assert.strictEqual(levenshteinDistance("", ""), 0);
    });

    test("returns length of other string when one is empty", function (assert) {
      assert.strictEqual(levenshteinDistance("", "hello"), 5);
      assert.strictEqual(levenshteinDistance("world", ""), 5);
    });

    test("returns 1 for single character difference", function (assert) {
      assert.strictEqual(levenshteinDistance("condition", "conditions"), 1);
      assert.strictEqual(levenshteinDistance("cat", "bat"), 1);
      assert.strictEqual(levenshteinDistance("cats", "cat"), 1);
    });

    test("returns 2 for two character differences", function (assert) {
      assert.strictEqual(levenshteinDistance("codition", "conditions"), 2);
      assert.strictEqual(levenshteinDistance("cat", "dog"), 3);
    });

    test("handles transpositions", function (assert) {
      assert.strictEqual(levenshteinDistance("conditons", "conditions"), 1);
    });

    test("handles classic example: kitten to sitting", function (assert) {
      assert.strictEqual(levenshteinDistance("kitten", "sitting"), 3);
    });
  });

  module("findClosestMatch", function () {
    const candidates = ["block", "args", "children", "conditions", "name"];

    test("returns exact match with distance 0", function (assert) {
      assert.strictEqual(findClosestMatch("block", candidates), "block");
      assert.strictEqual(
        findClosestMatch("conditions", candidates),
        "conditions"
      );
    });

    test("returns closest match within threshold", function (assert) {
      assert.strictEqual(
        findClosestMatch("condition", candidates),
        "conditions"
      );
      assert.strictEqual(
        findClosestMatch("conditon", candidates),
        "conditions"
      );
      assert.strictEqual(findClosestMatch("blok", candidates), "block");
    });

    test("returns null when no match within threshold", function (assert) {
      assert.strictEqual(findClosestMatch("foo", candidates), null);
      assert.strictEqual(findClosestMatch("xyz", candidates), null);
      assert.strictEqual(
        findClosestMatch("completely_different", candidates),
        null
      );
    });

    test("respects minSimilarity option", function (assert) {
      // "condition" vs "conditions" has high similarity (~0.97)
      assert.strictEqual(
        findClosestMatch("condition", candidates, { minSimilarity: 0.95 }),
        "conditions"
      );
      // With very high threshold, even close matches are rejected
      assert.strictEqual(
        findClosestMatch("conditon", candidates, { minSimilarity: 0.99 }),
        null
      );
      // With lower threshold, more distant matches are accepted
      assert.strictEqual(
        findClosestMatch("conditon", candidates, { minSimilarity: 0.8 }),
        "conditions"
      );
    });

    test("is case insensitive by default", function (assert) {
      assert.strictEqual(findClosestMatch("BLOCK", candidates), "block");
      assert.strictEqual(
        findClosestMatch("CONDITIONS", candidates),
        "conditions"
      );
      assert.strictEqual(
        findClosestMatch("Condition", candidates),
        "conditions"
      );
    });

    test("respects caseSensitive option", function (assert) {
      assert.strictEqual(
        findClosestMatch("BLOCK", candidates, { caseSensitive: true }),
        null
      );
      assert.strictEqual(
        findClosestMatch("block", candidates, { caseSensitive: true }),
        "block"
      );
    });

    test("returns closest when multiple matches within threshold", function (assert) {
      // Test with distinct candidates where best match is unambiguous
      const testCandidates = ["settings", "conditions", "arguments"];
      // "settins" is clearly closest to "settings" (1 char diff)
      assert.strictEqual(
        findClosestMatch("settins", testCandidates),
        "settings"
      );
      // "conditons" is clearly closest to "conditions"
      assert.strictEqual(
        findClosestMatch("conditons", testCandidates),
        "conditions"
      );
    });

    test("handles empty candidates array", function (assert) {
      assert.strictEqual(findClosestMatch("anything", []), null);
    });

    test("handles single candidate", function (assert) {
      assert.strictEqual(
        findClosestMatch("condition", ["conditions"]),
        "conditions"
      );
      assert.strictEqual(findClosestMatch("xyz", ["conditions"]), null);
    });
  });

  module("formatWithSuggestion", function () {
    const validValues = ["block", "args", "conditions"];

    test("formats with suggestion when close match found", function (assert) {
      assert.strictEqual(
        formatWithSuggestion("condition", validValues),
        '"condition" (did you mean "conditions"?)'
      );
      assert.strictEqual(
        formatWithSuggestion("conditon", validValues),
        '"conditon" (did you mean "conditions"?)'
      );
      assert.strictEqual(
        formatWithSuggestion("blok", validValues),
        '"blok" (did you mean "block"?)'
      );
    });

    test("formats without suggestion when no close match", function (assert) {
      assert.strictEqual(formatWithSuggestion("foo", validValues), '"foo"');
      assert.strictEqual(formatWithSuggestion("xyz", validValues), '"xyz"');
    });

    test("passes options to findClosestMatch", function (assert) {
      // With very high threshold, no suggestion is returned
      assert.strictEqual(
        formatWithSuggestion("codition", validValues, { minSimilarity: 0.99 }),
        '"codition"'
      );
      // With lower threshold, suggestion is returned
      assert.strictEqual(
        formatWithSuggestion("codition", validValues, { minSimilarity: 0.8 }),
        '"codition" (did you mean "conditions"?)'
      );
    });

    test("handles empty validValues array", function (assert) {
      assert.strictEqual(formatWithSuggestion("anything", []), '"anything"');
    });

    test("handles exact match", function (assert) {
      assert.strictEqual(
        formatWithSuggestion("block", validValues),
        '"block" (did you mean "block"?)'
      );
    });
  });
});
