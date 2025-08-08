import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import FilterSuggestions from "discourse/lib/filter-suggestions";

function buildTips() {
  return [
    {
      name: "category:",
      description: "Pick a category",
      type: "category",
      priority: 1,
    },
    {
      name: "tag:",
      description: "Pick tags",
      type: "tag",
      priority: 1,
      delimiters: [
        { name: ",", description: "add" },
        { name: "+", description: "add" },
      ],
    },
    {
      name: "status:solved",
      description: "Solved topics",
      type: "text",
      priority: 1,
    },
    {
      name: "status:unsolved",
      description: "Unsolved topics",
      type: "text",
      priority: 1,
    },
    {
      name: "after:",
      description: "Filter by date",
      type: "date",
      priority: 1,
    },
    { name: "min:", description: "Min number", type: "number" },
  ];
}

function buildContext() {
  return {
    site: {
      categories: [
        { id: 1, name: "Support", slug: "support" },
        { id: 2, name: "Meta", slug: "meta" },
      ],
    },
  };
}

module("Unit | Utility | filter-suggestions", function (hooks) {
  setupTest(hooks);

  test("top-level tips for empty input are priority=1 and sorted by name", async function (assert) {
    const tips = buildTips();

    const { suggestions } = await FilterSuggestions.getSuggestions(
      "",
      tips,
      buildContext()
    );
    const names = suggestions.map((s) => s.name);

    assert.deepEqual(
      names,
      ["after:", "category:", "status:solved", "status:unsolved", "tag:"],
      "returns only top-level tips sorted alphabetically within same priority"
    );
  });

  test("trailing space switches back to top-level tips", async function (assert) {
    const tips = buildTips();
    const baseline = await FilterSuggestions.getSuggestions(
      "",
      tips,
      buildContext()
    );

    const { suggestions, activeFilter } =
      await FilterSuggestions.getSuggestions(
        "category:support ",
        tips,
        buildContext()
      );

    assert.strictEqual(
      activeFilter,
      null,
      "no active filter after trailing space"
    );
    assert.deepEqual(
      suggestions.map((s) => s.name),
      baseline.suggestions.map((s) => s.name),
      "shows top-level tips after trailing space"
    );
  });

  test("category value suggestions match category slug and set activeFilter", async function (assert) {
    const tips = buildTips();

    const { suggestions, activeFilter } =
      await FilterSuggestions.getSuggestions(
        "category:sup",
        tips,
        buildContext()
      );
    const slugs = suggestions.map((s) => s.term);

    assert.strictEqual(activeFilter, "category", "activeFilter is category");
    assert.true(slugs.includes("support"), "suggests matching category");
    assert.true(suggestions[0].isSuggestion, "marks as suggestion items");
  });

  test("date suggestions filter by value and description", async function (assert) {
    const tips = buildTips();

    const valueFiltered = await FilterSuggestions.getSuggestions(
      "after:7",
      tips,
      buildContext()
    );
    assert.true(
      valueFiltered.suggestions.some((s) => s.term === "7"),
      "includes 7 when filtering by value"
    );

    const descFiltered = await FilterSuggestions.getSuggestions(
      "after:week",
      tips,
      buildContext()
    );
    assert.true(
      descFiltered.suggestions.length > 0,
      "filters by description substring"
    );
  });

  test("number suggestions include defaults and filter by partial", async function (assert) {
    const tips = buildTips();

    const defaults = await FilterSuggestions.getSuggestions(
      "min:",
      tips,
      buildContext()
    );
    assert.deepEqual(
      defaults.suggestions.map((s) => s.term),
      ["0", "1", "5", "10", "20"],
      "default number options are provided"
    );

    const filtered = await FilterSuggestions.getSuggestions(
      "min:1",
      tips,
      buildContext()
    );
    assert.true(
      filtered.suggestions.some((s) => s.term === "1"),
      "includes number matching partial"
    );
  });

  test("filtering tips by partial name returns matching tips", async function (assert) {
    const tips = buildTips();

    const { suggestions } = await FilterSuggestions.getSuggestions(
      "sta",
      tips,
      buildContext()
    );
    const names = suggestions.map((s) => s.name);

    assert.true(names.includes("status:solved"), "includes status:solved");
    assert.true(names.includes("status:unsolved"), "includes status:unsolved");
  });

  test("top-level tips are limited to 20", async function (assert) {
    const many = [];
    for (let i = 0; i < 30; i++) {
      many.push({
        name: `z${i}:`,
        description: "x",
        type: "text",
        priority: 1,
      });
    }

    const { suggestions } = await FilterSuggestions.getSuggestions(
      "",
      many,
      buildContext()
    );
    assert.strictEqual(suggestions.length, 20, "limits results to 20");
  });
});
