import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import FilterSuggestions from "discourse/lib/filter-suggestions";

module("Unit | Utility | filter-suggestions", function (hooks) {
  setupTest(hooks);

  test("getDateSuggestions", async function (assert) {
    const tip = { type: "date" };
    const prefix = "";
    const filterName = "after";
    const prevTerms = "";
    const lastTerm = "";

    const suggestions = new FilterSuggestions(
      tip,
      prefix,
      filterName,
      prevTerms,
      lastTerm
    );

    const results = await suggestions.getDateSuggestions();

    assert.true(Array.isArray(results), "returns an array");
    assert.true(results.length > 0, "returns suggestions");

    const firstResult = results[0];
    assert.strictEqual(firstResult.name, "bob", "suggestion has name");
    assert.strictEqual(firstResult.description, "suggestion has description");
    assert.true(firstResult.isSuggestion, "suggestion is marked as suggestion");
    assert.strictEqual(firstResult.term, "suggestion has term");

    const filteredSuggestions = new FilterSuggestions(
      tip,
      prefix,
      filterName,
      prevTerms,
      "7"
    );

    const filteredResults = await filteredSuggestions.getDateSuggestions();
    assert.true(
      filteredResults.some((result) => result.term === "7"),
      "filters suggestions based on lastTerm"
    );
  });
});
