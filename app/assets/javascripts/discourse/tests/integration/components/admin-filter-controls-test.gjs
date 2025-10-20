import { click, fillIn, render, select } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import AdminFilterControls from "admin/components/admin-filter-controls";

const SAMPLE_DATA = [
  {
    id: 1,
    name: "First Item",
    description: "This is the first item",
    category: "feature",
    enabled: true,
  },
  {
    id: 2,
    name: "Second Item",
    description: "This is the second item",
    category: "other",
    enabled: false,
  },
  {
    id: 3,
    name: "Third Item",
    description: "This is the third item",
    category: "feature",
    enabled: true,
  },
];

const SAMPLE_DROPDOWN_OPTIONS = [
  { label: "All", value: "all", filterFn: () => true },
  {
    label: "Feature",
    value: "feature",
    filterFn: (item) => item.category === "feature",
  },
  {
    label: "Other",
    value: "other",
    filterFn: (item) => item.category === "other",
  },
];

module("Integration | Component | AdminFilterControls", function (hooks) {
  setupRenderingTest(hooks);

  test("renders text filter input", async function (assert) {
    const self = this;
    this.set("data", SAMPLE_DATA);

    await render(
      <template>
        <AdminFilterControls @array={{self.data}} @inputPlaceholder="Search...">
          <:content as |filteredData|>
            <div class="results">
              {{#each filteredData as |item|}}
                <div class="item" data-id={{item.id}}>{{item.name}}</div>
              {{/each}}
            </div>
          </:content>
        </AdminFilterControls>
      </template>
    );

    assert
      .dom(".admin-filter-controls__input")
      .exists("renders text filter input");
    assert
      .dom(".filter-input")
      .hasAttribute("placeholder", "Search...", "has correct placeholder");
  });

  test("filters data by text (client-side)", async function (assert) {
    const self = this;
    this.set("data", SAMPLE_DATA);
    this.set("searchableProps", ["name", "description"]);

    await render(
      <template>
        <AdminFilterControls
          @array={{self.data}}
          @searchableProps={{self.searchableProps}}
          @inputPlaceholder="Search..."
        >
          <:content as |filteredData|>
            <div class="results">
              {{#each filteredData as |item|}}
                <div class="item" data-id={{item.id}}>{{item.name}}</div>
              {{/each}}
            </div>
          </:content>
        </AdminFilterControls>
      </template>
    );

    assert.dom(".item").exists({ count: 3 }, "shows all items initially");

    await fillIn(".filter-input", "first");

    assert
      .dom(".item")
      .exists({ count: 1 }, "shows only matching items after filtering");
    assert.dom(".item[data-id='1']").exists("shows the correct filtered item");
  });

  test("renders single dropdown filter", async function (assert) {
    const self = this;
    this.set("data", SAMPLE_DATA);
    this.set("dropdownOptions", SAMPLE_DROPDOWN_OPTIONS);

    await render(
      <template>
        <AdminFilterControls
          @array={{self.data}}
          @dropdownOptions={{self.dropdownOptions}}
        >
          <:content as |filteredData|>
            <div class="results">
              {{#each filteredData as |item|}}
                <div class="item" data-id={{item.id}}>{{item.name}}</div>
              {{/each}}
            </div>
          </:content>
        </AdminFilterControls>
      </template>
    );

    assert
      .dom(".admin-filter-controls__dropdown")
      .exists("renders dropdown filter");
  });

  test("filters data by single dropdown (client-side)", async function (assert) {
    const self = this;
    this.set("data", SAMPLE_DATA);
    this.set("dropdownOptions", SAMPLE_DROPDOWN_OPTIONS);

    await render(
      <template>
        <AdminFilterControls
          @array={{self.data}}
          @dropdownOptions={{self.dropdownOptions}}
        >
          <:content as |filteredData|>
            <div class="results">
              {{#each filteredData as |item|}}
                <div class="item" data-id={{item.id}}>{{item.name}}</div>
              {{/each}}
            </div>
          </:content>
        </AdminFilterControls>
      </template>
    );

    assert.dom(".item").exists({ count: 3 }, "shows all items initially");

    await select(".admin-filter-controls__dropdown", "feature");

    assert
      .dom(".item")
      .exists(
        { count: 2 },
        "shows only feature items after dropdown selection"
      );
    assert.dom(".item[data-id='1']").exists("shows first feature item");
    assert.dom(".item[data-id='3']").exists("shows second feature item");
  });

  test("combines text and dropdown filters (client-side)", async function (assert) {
    const self = this;
    this.set("data", SAMPLE_DATA);
    this.set("searchableProps", ["name", "description"]);
    this.set("dropdownOptions", SAMPLE_DROPDOWN_OPTIONS);

    await render(
      <template>
        <AdminFilterControls
          @array={{self.data}}
          @searchableProps={{self.searchableProps}}
          @dropdownOptions={{self.dropdownOptions}}
        >
          <:content as |filteredData|>
            <div class="results">
              {{#each filteredData as |item|}}
                <div class="item" data-id={{item.id}}>{{item.name}}</div>
              {{/each}}
            </div>
          </:content>
        </AdminFilterControls>
      </template>
    );

    assert.dom(".item").exists({ count: 3 }, "shows all items initially");

    await select(".admin-filter-controls__dropdown", "feature");

    assert
      .dom(".item")
      .exists({ count: 2 }, "shows only feature items after dropdown");

    await fillIn(".filter-input", "third");

    assert
      .dom(".item")
      .exists({ count: 1 }, "shows only items matching both text and dropdown");
    assert.dom(".item[data-id='3']").exists("shows the correct item");
  });

  test("shows reset button when filters are active", async function (assert) {
    const self = this;
    this.set("data", SAMPLE_DATA);
    this.set("searchableProps", ["name"]);

    await render(
      <template>
        <AdminFilterControls
          @array={{self.data}}
          @searchableProps={{self.searchableProps}}
        >
          <:content as |filteredData|>
            <div class="results">
              {{#each filteredData as |item|}}
                <div class="item" data-id={{item.id}}>{{item.name}}</div>
              {{/each}}
            </div>
          </:content>
        </AdminFilterControls>
      </template>
    );

    assert
      .dom(".admin-filter-controls__reset")
      .doesNotExist("no reset button initially");

    await fillIn(".filter-input", "nonexistent");

    assert
      .dom(".admin-filter-controls__no-results")
      .exists("shows no results message");
    assert
      .dom(".admin-filter-controls__reset")
      .exists("shows reset button after filtering");
  });

  test("reset button clears filters", async function (assert) {
    const self = this;
    this.set("data", SAMPLE_DATA);
    this.set("searchableProps", ["name"]);

    await render(
      <template>
        <AdminFilterControls
          @array={{self.data}}
          @searchableProps={{self.searchableProps}}
        >
          <:content as |filteredData|>
            <div class="results">
              {{#each filteredData as |item|}}
                <div class="item" data-id={{item.id}}>{{item.name}}</div>
              {{/each}}
            </div>
          </:content>
        </AdminFilterControls>
      </template>
    );

    await fillIn(".filter-input", "first");

    assert.dom(".item").exists({ count: 1 }, "shows filtered results");

    await fillIn(".filter-input", "firstblah");
    assert
      .dom(".item")
      .doesNotExist("does not show any results when filters find none");

    await click(".admin-filter-controls__reset");

    assert.dom(".item").exists({ count: 3 }, "shows all items after reset");
    assert.dom(".filter-input").hasValue("", "clears text input");
  });

  test("respects minItemsForFilter parameter", async function (assert) {
    const self = this;
    this.set("data", [SAMPLE_DATA[0]]);

    await render(
      <template>
        <AdminFilterControls @array={{self.data}} @minItemsForFilter={{2}}>
          <:content as |filteredData|>
            <div class="results">
              {{#each filteredData as |item|}}
                <div class="item" data-id={{item.id}}>{{item.name}}</div>
              {{/each}}
            </div>
          </:content>
        </AdminFilterControls>
      </template>
    );

    assert
      .dom(".admin-filter-controls")
      .doesNotExist("hides filters when items below minimum");
    assert
      .dom(".item")
      .exists({ count: 1 }, "still shows content even when filters are hidden");
  });

  test("calls onTextFilterChange callback for server-side filtering", async function (assert) {
    const self = this;
    this.set("data", SAMPLE_DATA);
    this.set("textFilterCallback", (event) => {
      assert.step(`text-filter:${event.target.value}`);
    });

    await render(
      <template>
        <AdminFilterControls
          @array={{self.data}}
          @onTextFilterChange={{self.textFilterCallback}}
        >
          <:content as |filteredData|>
            <div class="results">
              {{#each filteredData as |item|}}
                <div class="item" data-id={{item.id}}>{{item.name}}</div>
              {{/each}}
            </div>
          </:content>
        </AdminFilterControls>
      </template>
    );

    await fillIn(".filter-input", "test");

    assert.verifySteps(["text-filter:test"], "calls callback with value");
  });

  test("calls onDropdownFilterChange callback for server-side filtering", async function (assert) {
    const self = this;
    this.set("data", SAMPLE_DATA);
    this.set("dropdownOptions", [
      { label: "All", value: "all" },
      { label: "Feature", value: "feature" },
    ]);
    this.set("dropdownFilterCallback", (value) => {
      assert.step(`dropdown-filter:${value}`);
    });

    await render(
      <template>
        <AdminFilterControls
          @array={{self.data}}
          @dropdownOptions={{self.dropdownOptions}}
          @onDropdownFilterChange={{self.dropdownFilterCallback}}
        >
          <:content as |filteredData|>
            <div class="results">
              {{#each filteredData as |item|}}
                <div class="item" data-id={{item.id}}>{{item.name}}</div>
              {{/each}}
            </div>
          </:content>
        </AdminFilterControls>
      </template>
    );

    await select(".admin-filter-controls__dropdown", "feature");

    assert.verifySteps(
      ["dropdown-filter:feature"],
      "calls callback with selected value"
    );
  });

  test("calls onResetFilters callback for server-side filtering", async function (assert) {
    const self = this;
    this.set("data", SAMPLE_DATA);
    this.set("searchableProps", ["name"]);
    this.set("resetCallback", () => {
      assert.step("reset-filters");
    });

    await render(
      <template>
        <AdminFilterControls
          @array={{self.data}}
          @searchableProps={{self.searchableProps}}
          @onResetFilters={{self.resetCallback}}
        >
          <:content as |filteredData|>
            <div class="results">
              {{#each filteredData as |item|}}
                <div class="item" data-id={{item.id}}>{{item.name}}</div>
              {{/each}}
            </div>
          </:content>
        </AdminFilterControls>
      </template>
    );

    await fillIn(".filter-input", "test");
    await click(".admin-filter-controls__reset");

    assert.verifySteps(["reset-filters"], "calls reset callback");
  });

  test("skips client-side filtering when server callbacks provided", async function (assert) {
    const self = this;
    this.set("data", SAMPLE_DATA);
    this.set("searchableProps", ["name"]);
    this.set("textFilterCallback", () => {});

    await render(
      <template>
        <AdminFilterControls
          @array={{self.data}}
          @searchableProps={{self.searchableProps}}
          @onTextFilterChange={{self.textFilterCallback}}
        >
          <:content as |filteredData|>
            <div class="results">
              {{#each filteredData as |item|}}
                <div class="item" data-id={{item.id}}>{{item.name}}</div>
              {{/each}}
            </div>
          </:content>
        </AdminFilterControls>
      </template>
    );

    await fillIn(".filter-input", "first");

    assert
      .dom(".item")
      .exists(
        { count: 3 },
        "does not filter client-side when callback provided"
      );
  });

  test("yields to actions block", async function (assert) {
    const self = this;
    this.set("data", SAMPLE_DATA);

    await render(
      <template>
        <AdminFilterControls @array={{self.data}}>
          <:actions>
            <button type="button" class="custom-action">Custom Action</button>
          </:actions>
          <:content as |filteredData|>
            <div class="results">
              {{#each filteredData as |item|}}
                <div class="item">{{item.name}}</div>
              {{/each}}
            </div>
          </:content>
        </AdminFilterControls>
      </template>
    );

    assert
      .dom(".custom-action")
      .exists("renders custom actions in actions block");
  });

  test("yields to aboveContent block", async function (assert) {
    const self = this;
    this.set("data", SAMPLE_DATA);

    await render(
      <template>
        <AdminFilterControls @array={{self.data}}>
          <:aboveContent>
            <div class="above-content">Above Content Area</div>
          </:aboveContent>
          <:content as |filteredData|>
            <div class="results">
              {{#each filteredData as |item|}}
                <div class="item">{{item.name}}</div>
              {{/each}}
            </div>
          </:content>
        </AdminFilterControls>
      </template>
    );

    assert
      .dom(".above-content")
      .exists("renders content in aboveContent block");
  });

  test("shows custom no results message", async function (assert) {
    const self = this;
    this.set("data", SAMPLE_DATA);
    this.set("searchableProps", ["name"]);

    await render(
      <template>
        <AdminFilterControls
          @array={{self.data}}
          @searchableProps={{self.searchableProps}}
          @noResultsMessage="No items found matching your criteria"
        >
          <:content as |filteredData|>
            <div class="results">
              {{#each filteredData as |item|}}
                <div class="item">{{item.name}}</div>
              {{/each}}
            </div>
          </:content>
        </AdminFilterControls>
      </template>
    );

    await fillIn(".filter-input", "nonexistent");

    assert
      .dom(".admin-filter-controls__no-results p")
      .hasText(
        "No items found matching your criteria",
        "shows custom no results message"
      );
  });

  test("does not show dropdown filter when only one option", async function (assert) {
    const self = this;
    this.set("data", SAMPLE_DATA);
    this.set("dropdownOptions", [{ label: "All", value: "all" }]);

    await render(
      <template>
        <AdminFilterControls
          @array={{self.data}}
          @dropdownOptions={{self.dropdownOptions}}
        >
          <:content as |filteredData|>
            <div class="results">
              {{#each filteredData as |item|}}
                <div class="item">{{item.name}}</div>
              {{/each}}
            </div>
          </:content>
        </AdminFilterControls>
      </template>
    );

    assert
      .dom(".admin-filter-controls__dropdown")
      .doesNotExist("hides dropdown when only one option");
  });

  test("renders multiple dropdowns", async function (assert) {
    const self = this;
    this.set("data", SAMPLE_DATA);
    this.set("dropdownOptions", {
      category: [
        { label: "All", value: "all" },
        { label: "Feature", value: "feature" },
      ],
      enabled: [
        { label: "All", value: "all" },
        { label: "Enabled", value: "enabled" },
      ],
    });

    await render(
      <template>
        <AdminFilterControls
          @array={{self.data}}
          @dropdownOptions={{self.dropdownOptions}}
        >
          <:content as |filteredData|>
            <div class="results">
              {{#each filteredData as |item|}}
                <div class="item">{{item.name}}</div>
              {{/each}}
            </div>
          </:content>
        </AdminFilterControls>
      </template>
    );

    assert
      .dom(".admin-filter-controls__dropdown")
      .exists({ count: 2 }, "renders two dropdowns");
    assert
      .dom(".admin-filter-controls__dropdown--category")
      .exists("renders category dropdown");
    assert
      .dom(".admin-filter-controls__dropdown--enabled")
      .exists("renders enabled dropdown");
  });

  test("filters data by multiple dropdowns (client-side)", async function (assert) {
    const self = this;
    this.set("data", SAMPLE_DATA);
    this.set("dropdownOptions", {
      category: [
        { label: "All", value: "all", filterFn: () => true },
        {
          label: "Feature",
          value: "feature",
          filterFn: (item) => item.category === "feature",
        },
      ],
      enabled: [
        { label: "All", value: "all", filterFn: () => true },
        {
          label: "Enabled",
          value: "enabled",
          filterFn: (item) => item.enabled,
        },
      ],
    });

    await render(
      <template>
        <AdminFilterControls
          @array={{self.data}}
          @dropdownOptions={{self.dropdownOptions}}
        >
          <:content as |filteredData|>
            <div class="results">
              {{#each filteredData as |item|}}
                <div class="item" data-id={{item.id}}>{{item.name}}</div>
              {{/each}}
            </div>
          </:content>
        </AdminFilterControls>
      </template>
    );

    assert.dom(".item").exists({ count: 3 }, "shows all items initially");

    await select(".admin-filter-controls__dropdown--category", "feature");

    assert
      .dom(".item")
      .exists({ count: 2 }, "shows only feature items after category filter");

    await select(".admin-filter-controls__dropdown--enabled", "enabled");

    assert
      .dom(".item")
      .exists(
        { count: 2 },
        "shows only enabled feature items after both filters"
      );
    assert.dom(".item[data-id='1']").exists("shows first enabled feature");
    assert.dom(".item[data-id='3']").exists("shows second enabled feature");
  });

  test("resets multiple dropdowns correctly", async function (assert) {
    const self = this;
    this.set("data", SAMPLE_DATA);
    this.set("searchableProps", ["name"]);
    this.set("dropdownOptions", {
      category: [
        { label: "All", value: "all", filterFn: () => true },
        {
          label: "Feature",
          value: "feature",
          filterFn: (item) => item.category === "feature",
        },
      ],
    });

    await render(
      <template>
        <AdminFilterControls
          @array={{self.data}}
          @searchableProps={{self.searchableProps}}
          @dropdownOptions={{self.dropdownOptions}}
        >
          <:content as |filteredData|>
            <div class="results">
              {{#each filteredData as |item|}}
                <div class="item" data-id={{item.id}}>{{item.name}}</div>
              {{/each}}
            </div>
          </:content>
        </AdminFilterControls>
      </template>
    );

    await select(".admin-filter-controls__dropdown--category", "feature");
    await fillIn(".filter-input", "first");

    assert.dom(".item").exists({ count: 1 }, "shows filtered results");

    await fillIn(".filter-input", "firstblah");
    await click(".admin-filter-controls__reset");

    assert.dom(".item").exists({ count: 3 }, "shows all items after reset");
  });

  test("calls onDropdownFilterChange with key and value for multiple dropdowns", async function (assert) {
    const self = this;
    this.set("data", SAMPLE_DATA);
    this.set("dropdownOptions", {
      category: [
        { label: "All", value: "all" },
        { label: "Feature", value: "feature" },
      ],
      enabled: [
        { label: "All", value: "all" },
        { label: "Enabled", value: "enabled" },
      ],
    });
    this.set("dropdownFilterCallback", (key, value) => {
      assert.step(`dropdown-filter:${key}:${value}`);
    });

    await render(
      <template>
        <AdminFilterControls
          @array={{self.data}}
          @dropdownOptions={{self.dropdownOptions}}
          @onDropdownFilterChange={{self.dropdownFilterCallback}}
        >
          <:content as |filteredData|>
            <div class="results">
              {{#each filteredData as |item|}}
                <div class="item">{{item.name}}</div>
              {{/each}}
            </div>
          </:content>
        </AdminFilterControls>
      </template>
    );

    await select(".admin-filter-controls__dropdown--category", "feature");
    await select(".admin-filter-controls__dropdown--enabled", "enabled");

    assert.verifySteps(
      ["dropdown-filter:category:feature", "dropdown-filter:enabled:enabled"],
      "calls callback with key and value for each dropdown"
    );
  });

  test("supports custom default values for multiple dropdowns", async function (assert) {
    const self = this;
    this.set("data", SAMPLE_DATA);
    this.set("dropdownOptions", {
      category: [
        { label: "All", value: "all", filterFn: () => true },
        {
          label: "Feature",
          value: "feature",
          filterFn: (item) => item.category === "feature",
        },
      ],
    });
    this.set("defaultDropdownValue", { category: "feature" });

    await render(
      <template>
        <AdminFilterControls
          @array={{self.data}}
          @dropdownOptions={{self.dropdownOptions}}
          @defaultDropdownValue={{self.defaultDropdownValue}}
        >
          <:content as |filteredData|>
            <div class="results">
              {{#each filteredData as |item|}}
                <div class="item" data-id={{item.id}}>{{item.name}}</div>
              {{/each}}
            </div>
          </:content>
        </AdminFilterControls>
      </template>
    );

    assert
      .dom(".item")
      .exists(
        { count: 2 },
        "shows only feature items initially because of defaultDropdownValue"
      );

    await select(".admin-filter-controls__dropdown--category", "all");

    assert
      .dom(".item")
      .exists({ count: 3 }, "shows all items after changing filter");
  });
});
