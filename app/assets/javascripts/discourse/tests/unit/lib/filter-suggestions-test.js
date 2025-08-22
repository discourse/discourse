import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import FilterSuggestions from "discourse/lib/filter-suggestions";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

function buildTips() {
  return [
    {
      name: "category:",
      description: "Pick a category",
      type: "category",
      priority: 1,
      prefixes: [
        { name: "-", description: "exclude category" },
        { name: "=", description: "no subcategories" },
      ],
    },
    {
      name: "tag:",
      description: "Pick tags",
      type: "tag",
      priority: 1,
      delimiters: [
        { name: ",", description: "add" },
        { name: "+", description: "intersect" },
      ],
    },
    { name: "status:", description: "Pick a status" },
    {
      name: "status:solved",
      description: "Solved topics",
      priority: 1,
    },
    {
      name: "status:unsolved",
      description: "Unsolved topics",
      priority: 1,
    },
    {
      name: "users:",
      description: "Users",
      type: "username",
      priority: 1,
      delimiters: [
        { name: ",", description: "any" },
        { name: "+", description: "all" },
      ],
    },
    {
      name: "group:",
      alias: "groups:",
      description: "Group",
      type: "group",
      priority: 1,
      delimiters: [
        { name: ",", description: "any" },
        { name: "+", description: "all" },
      ],
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

module("Unit | Utility | FilterSuggestions", function (hooks) {
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
      [
        "after:",
        "category:",
        "group:",
        "status:solved",
        "status:unsolved",
        "tag:",
        "users:",
      ],
      "returns only top-level tips sorted alphabetically within same priority"
    );
  });

  test("-cat finds -categories", async function (assert) {
    const tips = buildTips();
    const { suggestions, activeFilter } =
      await FilterSuggestions.getSuggestions("-cat", tips, buildContext());
    const names = suggestions.map((s) => s.name);

    assert.deepEqual(names, ["-category:"], "returns only -category: for -cat");
    assert.strictEqual(activeFilter, null, "activeFilter is not set yet");
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

  test("prefix filters works as expected", async function (assert) {
    const tips = buildTips();
    const { suggestions, activeFilter } =
      await FilterSuggestions.getSuggestions("cat", tips, buildContext());
    const names = suggestions.map((s) => s.name);

    assert.deepEqual(names, ["category:", "-category:", "=category:"]);
    assert.strictEqual(activeFilter, null, "activeFilter is not set yet");
  });

  test("does not show suggestions for already matched filters", async function (assert) {
    const tips = buildTips();
    const { suggestions, activeFilter } =
      await FilterSuggestions.getSuggestions("status:", tips, buildContext());
    const names = suggestions.map((s) => s.name);
    assert.deepEqual(
      names,
      ["status:solved", "status:unsolved"],
      "shows only status suggestions"
    );

    assert.strictEqual(activeFilter, null, "activeFilter is not set yet");
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

  test("username suggestions include delimiters when exact match is present", async function (assert) {
    pretender.get("/u/search/users.json", () =>
      response({ users: [{ username: "sam", name: "Sam" }] })
    );

    const res = await FilterSuggestions.getSuggestions(
      "users:sam",
      buildTips(),
      buildContext()
    );
    const names = res.suggestions.map((s) => s.name);

    assert.true(names.includes("users:sam+"), "offers + delimiter");
    assert.true(names.includes("users:sam,"), "offers , delimiter");
  });

  test("group suggestions are fetched and include delimiters", async function (assert) {
    pretender.get("/groups/search.json", () =>
      response([{ name: "team", full_name: "Team" }])
    );

    const res = await FilterSuggestions.getSuggestions(
      "group:te",
      buildTips(),
      buildContext()
    );
    const names = res.suggestions.map((s) => s.name);

    assert.true(names.includes("group:team"), "includes group name suggestion");
  });

  test("username_group_list suggests users and filters out already-used values", async function (assert) {
    pretender.get("/u/search/users.json", () =>
      response({
        users: [
          { username: "sam", name: "Sam" },
          { username: "cam", name: "Cam" },
        ],
      })
    );
    pretender.get("/groups/search.json", () => response([]));

    const tips = [
      {
        name: "assigned:",
        description: "Assigned",
        type: "username_group_list",
        priority: 1,
        delimiters: [{ name: ",", description: "add" }],
      },
    ];

    const first = await FilterSuggestions.getSuggestions(
      "assigned:am",
      tips,
      buildContext()
    );
    const firstTerms = first.suggestions.map((s) => s.term);

    assert.true(firstTerms.includes("sam"), "finds user sam");
    assert.true(firstTerms.includes("cam"), "finds user cam");

    const second = await FilterSuggestions.getSuggestions(
      "assigned:cam,",
      tips,
      buildContext()
    );
    const secondTerms = second.suggestions.map((s) => s.term);

    assert.true(secondTerms.includes("sam"), "sam remains available");
    assert.false(
      secondTerms.includes("cam"),
      "cam is excluded after being used"
    );
  });
});
