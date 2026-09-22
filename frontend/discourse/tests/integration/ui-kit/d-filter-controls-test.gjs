import { tracked } from "@glimmer/tracking";
import Evented from "@ember/object/evented";
import Service from "@ember/service";
import { click, fillIn, render, select, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DFilterControls from "discourse/ui-kit/d-filter-controls";
import { i18n } from "discourse-i18n";

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

class RouterStub extends Service.extend(Evented) {
  @tracked currentURL = "/admin/example";

  changeURL(url) {
    this.currentURL = url;
    this.trigger("routeDidChange");
  }
}

module("Integration | ui-kit | DFilterControls", function (hooks) {
  setupRenderingTest(hooks);

  test("renders text filter input", async function (assert) {
    this.set("data", SAMPLE_DATA);

    await render(
      <template>
        <DFilterControls @array={{this.data}} @inputPlaceholder="Search...">
          <:content as |filteredData|>
            <div class="results">
              {{#each filteredData as |item|}}
                <div class="item" data-id={{item.id}}>{{item.name}}</div>
              {{/each}}
            </div>
          </:content>
        </DFilterControls>
      </template>
    );

    assert.dom(".d-filter-controls__input").exists("renders text filter input");
    assert
      .dom(".filter-input")
      .hasAttribute("placeholder", "Search...", "has correct placeholder");
  });

  test("can hide the text filter without affecting other controls", async function (assert) {
    this.set("data", SAMPLE_DATA);
    this.set("dropdownOptions", {
      category: SAMPLE_DROPDOWN_OPTIONS,
    });
    this.set("resetCount", 0);
    this.set("onReset", () => this.set("resetCount", this.resetCount + 1));

    await render(
      <template>
        <DFilterControls
          @array={{this.data}}
          @dropdownOptions={{this.dropdownOptions}}
          @onResetFilters={{this.onReset}}
          @showTextFilter={{false}}
        >
          <:actions>
            <button class="custom-action" type="button">Custom action</button>
          </:actions>
          <:content as |filteredData|>
            <div class="results">{{filteredData.length}}</div>
          </:content>
        </DFilterControls>
      </template>
    );

    assert
      .dom(".d-filter-controls__input")
      .doesNotExist("hides the text input");
    assert
      .dom(".d-filter-controls__dropdown--category")
      .hasAttribute("aria-label", "All", "labels the dropdown filter");
    assert.dom(".custom-action").exists("renders yielded actions");
    assert.dom(".results").hasText("3", "renders yielded content");

    await select(".d-filter-controls__dropdown--category", "feature");
    await click(".d-filter-controls__reset");

    assert.strictEqual(this.resetCount, 1, "calls the reset callback once");
    assert
      .dom(".d-filter-controls__dropdown--category")
      .hasValue("all", "resets dropdown filters");
    assert
      .dom(".d-filter-controls__input")
      .doesNotExist("keeps the input hidden");
    assert
      .dom(".d-filter-controls__toggle-filters")
      .isFocused("moves focus to the remaining filter control");
  });

  test("does not render an empty inputs container when text filtering is hidden", async function (assert) {
    await render(
      <template>
        <DFilterControls @array={{SAMPLE_DATA}} @showTextFilter={{false}}>
          <:content as |filteredData|>
            <div class="results">{{filteredData.length}}</div>
          </:content>
        </DFilterControls>
      </template>
    );

    assert
      .dom(".d-filter-controls__inputs")
      .doesNotExist("omits the empty inputs container");
    assert.dom(".results").hasText("3", "still renders yielded content");
  });

  test("supports additional filters and includes them in reset state", async function (assert) {
    this.set("additionalFiltersActive", false);
    this.set("resetCount", 0);
    this.set("onReset", () => this.set("resetCount", this.resetCount + 1));

    await render(
      <template>
        <DFilterControls
          @additionalFiltersActive={{this.additionalFiltersActive}}
          @array={{SAMPLE_DATA}}
          @onResetFilters={{this.onReset}}
          @showTextFilter={{false}}
        >
          <:additionalFilters>
            <input aria-label="Custom filter" class="custom-filter" />
          </:additionalFilters>
        </DFilterControls>
      </template>
    );

    assert.dom(".custom-filter").exists("renders the additional filter");
    assert
      .dom(".d-filter-controls__reset")
      .isDisabled("disables reset while the additional filter is inactive");

    this.set("additionalFiltersActive", true);

    assert
      .dom(".d-filter-controls__reset")
      .isEnabled("enables reset while the additional filter is active");

    await click(".d-filter-controls__reset");

    assert.strictEqual(this.resetCount, 1, "calls the reset callback once");
  });

  test("filters data by text (client-side)", async function (assert) {
    this.set("data", SAMPLE_DATA);
    this.set("searchableProps", ["name", "description"]);

    await render(
      <template>
        <DFilterControls
          @array={{this.data}}
          @inputPlaceholder="Search..."
          @searchableProps={{this.searchableProps}}
        >
          <:content as |filteredData|>
            <div class="results">
              {{#each filteredData as |item|}}
                <div class="item" data-id={{item.id}}>{{item.name}}</div>
              {{/each}}
            </div>
          </:content>
        </DFilterControls>
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
    this.set("data", SAMPLE_DATA);
    this.set("dropdownOptions", SAMPLE_DROPDOWN_OPTIONS);

    await render(
      <template>
        <DFilterControls
          @array={{this.data}}
          @dropdownOptions={{this.dropdownOptions}}
        >
          <:content as |filteredData|>
            <div class="results">
              {{#each filteredData as |item|}}
                <div class="item" data-id={{item.id}}>{{item.name}}</div>
              {{/each}}
            </div>
          </:content>
        </DFilterControls>
      </template>
    );

    assert
      .dom(".d-filter-controls__dropdown")
      .exists("renders dropdown filter");
  });

  test("can collapse a single dropdown behind the filter toggle", async function (assert) {
    this.set("data", SAMPLE_DATA);
    this.set("dropdownOptions", SAMPLE_DROPDOWN_OPTIONS);

    await render(
      <template>
        <DFilterControls
          @array={{this.data}}
          @dropdownOptions={{this.dropdownOptions}}
          @filterDropdownsExpanded={{false}}
          @forceShowDropdownFilterToggle={{true}}
        />
      </template>
    );

    assert
      .dom(".d-filter-controls")
      .hasClass(
        "--dropdowns-in-filter-drawer",
        "uses the filter drawer layout"
      );
    assert
      .dom(".d-filter-controls__toggle-filters")
      .exists("shows the filter toggle");
    assert
      .dom(".d-filter-controls__dropdown")
      .doesNotExist("starts with the dropdown collapsed");

    await click(".d-filter-controls__toggle-filters");

    assert
      .dom(".d-filter-controls__dropdown")
      .exists("reveals the dropdown after toggling filters");

    await select(".d-filter-controls__dropdown", "feature");

    assert
      .dom(".d-filter-controls__reset")
      .exists({ count: 1 }, "shows a single reset button")
      .isEnabled("enables reset for the active dropdown");
    assert
      .dom(".d-filter-controls > .d-filter-controls__reset")
      .doesNotExist("does not duplicate reset outside the drawer controls");
  });

  test("can show expanded dropdowns without a filter toggle", async function (assert) {
    this.set("data", SAMPLE_DATA);
    this.set("dropdownOptions", {
      category: SAMPLE_DROPDOWN_OPTIONS,
      status: [
        { label: "All statuses", value: "all" },
        { label: "Enabled", value: "enabled" },
      ],
    });

    await render(
      <template>
        <DFilterControls
          @array={{this.data}}
          @dropdownOptions={{this.dropdownOptions}}
          @filterDropdownsExpanded={{true}}
          @showDropdownFilterToggle={{false}}
          @showTextFilter={{false}}
        />
      </template>
    );

    assert
      .dom(".d-filter-controls__toggle-filters")
      .doesNotExist("hides the filter toggle");
    assert
      .dom(".d-filter-controls__dropdown")
      .exists({ count: 2 }, "keeps the dropdowns expanded");

    await select(".d-filter-controls__dropdown--category", "feature");

    assert
      .dom(".d-filter-controls__reset")
      .exists({ count: 1 }, "shows reset when an expanded filter is active");
  });

  test("filters data by single dropdown (client-side)", async function (assert) {
    this.set("data", SAMPLE_DATA);
    this.set("dropdownOptions", SAMPLE_DROPDOWN_OPTIONS);

    await render(
      <template>
        <DFilterControls
          @array={{this.data}}
          @dropdownOptions={{this.dropdownOptions}}
        >
          <:content as |filteredData|>
            <div class="results">
              {{#each filteredData as |item|}}
                <div class="item" data-id={{item.id}}>{{item.name}}</div>
              {{/each}}
            </div>
          </:content>
        </DFilterControls>
      </template>
    );

    assert.dom(".item").exists({ count: 3 }, "shows all items initially");

    await select(".d-filter-controls__dropdown", "feature");

    assert
      .dom(".item")
      .exists(
        { count: 2 },
        "shows only feature items after dropdown selection"
      );
    assert.dom(".item[data-id='1']").exists("shows first feature item");
    assert.dom(".item[data-id='3']").exists("shows second feature item");
  });

  test("marks the dropdown active when its value differs from the default", async function (assert) {
    this.set("data", SAMPLE_DATA);
    this.set("dropdownOptions", SAMPLE_DROPDOWN_OPTIONS);

    await render(
      <template>
        <DFilterControls
          @array={{this.data}}
          @dropdownOptions={{this.dropdownOptions}}
        >
          <:content as |filteredData|>
            <div class="results">
              {{#each filteredData as |item|}}
                <div class="item" data-id={{item.id}}>{{item.name}}</div>
              {{/each}}
            </div>
          </:content>
        </DFilterControls>
      </template>
    );

    assert
      .dom(".d-filter-controls__dropdown.--active")
      .doesNotExist("not active while on the default option");

    await select(".d-filter-controls__dropdown", "feature");

    assert
      .dom(".d-filter-controls__dropdown.--active")
      .exists("active once a non-default option is chosen");
  });

  test("combines text and dropdown filters (client-side)", async function (assert) {
    this.set("data", SAMPLE_DATA);
    this.set("searchableProps", ["name", "description"]);
    this.set("dropdownOptions", SAMPLE_DROPDOWN_OPTIONS);

    await render(
      <template>
        <DFilterControls
          @array={{this.data}}
          @dropdownOptions={{this.dropdownOptions}}
          @searchableProps={{this.searchableProps}}
        >
          <:content as |filteredData|>
            <div class="results">
              {{#each filteredData as |item|}}
                <div class="item" data-id={{item.id}}>{{item.name}}</div>
              {{/each}}
            </div>
          </:content>
        </DFilterControls>
      </template>
    );

    assert.dom(".item").exists({ count: 3 }, "shows all items initially");

    await select(".d-filter-controls__dropdown", "feature");

    assert
      .dom(".item")
      .exists({ count: 2 }, "shows only feature items after dropdown");

    await fillIn(".filter-input", "third");

    assert
      .dom(".item")
      .exists({ count: 1 }, "shows only items matching both text and dropdown");
    assert.dom(".item[data-id='3']").exists("shows the correct item");
  });

  test("keeps reset visible and enables it only for active filters", async function (assert) {
    this.set("data", SAMPLE_DATA);
    this.set("searchableProps", ["name"]);

    await render(
      <template>
        <DFilterControls
          @array={{this.data}}
          @loading={{this.loading}}
          @searchableProps={{this.searchableProps}}
        >
          <:content as |filteredData|>
            <div class="results">
              {{#each filteredData as |item|}}
                <div class="item" data-id={{item.id}}>{{item.name}}</div>
              {{/each}}
            </div>
          </:content>
        </DFilterControls>
      </template>
    );

    assert
      .dom(".d-filter-controls__reset")
      .isDisabled("reset is visible and disabled initially");
    assert
      .dom(".d-filter-controls__reset .d-button-label")
      .doesNotExist("Reset has no visible text label");
    assert
      .dom(".d-filter-controls__reset")
      .hasAttribute(
        "title",
        i18n("filter_controls.reset"),
        "provides a tooltip"
      )
      .hasAttribute(
        "aria-label",
        i18n("filter_controls.reset"),
        "provides an accessible name"
      );

    await fillIn(".filter-input", "first");

    assert.dom(".item").exists({ count: 1 }, "filters matching items");
    assert
      .dom(".d-filter-controls > .d-filter-controls__reset")
      .isEnabled("enables reset when the search has results");

    this.set("loading", true);
    await settled();

    assert
      .dom(".d-filter-controls > .d-filter-controls__reset")
      .isEnabled("reset stays available during a reload");

    this.set("loading", false);
    await fillIn(".filter-input", "nonexistent");

    assert
      .dom(".d-filter-controls__no-results")
      .exists("shows no results message");
    assert
      .dom(".d-filter-controls__reset")
      .isEnabled("enables reset after filtering");
    assert
      .dom(".d-filter-controls__no-results .d-filter-controls__reset")
      .hasText(i18n("filter_controls.reset"), "labels the empty-state reset");
    assert
      .dom(".d-filter-controls > .d-filter-controls__reset .d-button-label")
      .doesNotExist("keeps the toolbar reset icon-only");

    await click(".d-filter-controls > .d-filter-controls__reset");

    assert
      .dom(".d-filter-controls__reset")
      .isDisabled("reset stays visible after restoring defaults");
    assert.dom(".item").exists({ count: 3 }, "restores all items");
    assert.dom(".filter-input").hasValue("", "clears the search");
  });

  test("can hide the built-in no-results state", async function (assert) {
    this.set("data", SAMPLE_DATA);
    this.set("searchableProps", ["name"]);

    await render(
      <template>
        <DFilterControls
          @array={{this.data}}
          @searchableProps={{this.searchableProps}}
          @showNoResults={{false}}
        />
      </template>
    );

    await fillIn(".filter-input", "nonexistent");

    assert
      .dom(".d-filter-controls > .d-filter-controls__reset")
      .exists({ count: 1 }, "shows one reset button beside the filters");
    assert
      .dom(".d-filter-controls__no-results")
      .doesNotExist("does not render the built-in no-results state");
  });

  test("can hide the reset button", async function (assert) {
    this.set("data", SAMPLE_DATA);
    this.set("searchableProps", ["name"]);

    await render(
      <template>
        <DFilterControls
          @array={{this.data}}
          @searchableProps={{this.searchableProps}}
          @showResetButton={{false}}
        />
      </template>
    );

    await fillIn(".filter-input", "nonexistent");

    assert
      .dom(".d-filter-controls__reset")
      .doesNotExist("does not render the reset button");
  });

  test("respects minItemsForFilter parameter", async function (assert) {
    this.set("data", [SAMPLE_DATA[0]]);

    await render(
      <template>
        <DFilterControls @array={{this.data}} @minItemsForFilter={{2}}>
          <:content as |filteredData|>
            <div class="results">
              {{#each filteredData as |item|}}
                <div class="item" data-id={{item.id}}>{{item.name}}</div>
              {{/each}}
            </div>
          </:content>
        </DFilterControls>
      </template>
    );

    assert
      .dom(".d-filter-controls")
      .doesNotExist("hides filters when items below minimum");
    assert
      .dom(".item")
      .exists({ count: 1 }, "still shows content even when filters are hidden");
  });

  test("calls onTextFilterChange callback for server-side filtering", async function (assert) {
    this.set("data", SAMPLE_DATA);
    this.set("textFilterCallback", (event) => {
      assert.step(`text-filter:${event.target.value}`);
    });

    await render(
      <template>
        <DFilterControls
          @array={{this.data}}
          @onTextFilterChange={{this.textFilterCallback}}
        >
          <:content as |filteredData|>
            <div class="results">
              {{#each filteredData as |item|}}
                <div class="item" data-id={{item.id}}>{{item.name}}</div>
              {{/each}}
            </div>
          </:content>
        </DFilterControls>
      </template>
    );

    await fillIn(".filter-input", "test");

    assert.verifySteps(["text-filter:test"], "calls callback with value");
  });

  test("calls onDropdownFilterChange callback for server-side filtering", async function (assert) {
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
        <DFilterControls
          @array={{this.data}}
          @dropdownOptions={{this.dropdownOptions}}
          @onDropdownFilterChange={{this.dropdownFilterCallback}}
        >
          <:content as |filteredData|>
            <div class="results">
              {{#each filteredData as |item|}}
                <div class="item" data-id={{item.id}}>{{item.name}}</div>
              {{/each}}
            </div>
          </:content>
        </DFilterControls>
      </template>
    );

    await select(".d-filter-controls__dropdown", "feature");

    assert.verifySteps(
      ["dropdown-filter:feature"],
      "calls callback with selected value"
    );
  });

  test("calls onResetFilters callback for server-side filtering", async function (assert) {
    this.set("data", SAMPLE_DATA);
    this.set("searchableProps", ["name"]);
    this.set("resetCallback", () => {
      assert.step("reset-filters");
    });

    await render(
      <template>
        <DFilterControls
          @array={{this.data}}
          @onResetFilters={{this.resetCallback}}
          @searchableProps={{this.searchableProps}}
        >
          <:content as |filteredData|>
            <div class="results">
              {{#each filteredData as |item|}}
                <div class="item" data-id={{item.id}}>{{item.name}}</div>
              {{/each}}
            </div>
          </:content>
        </DFilterControls>
      </template>
    );

    await fillIn(".filter-input", "test");
    await click(".d-filter-controls__reset");

    assert.verifySteps(["reset-filters"], "calls reset callback");
  });

  test("skips client-side filtering when server callbacks provided", async function (assert) {
    this.set("data", SAMPLE_DATA);
    this.set("searchableProps", ["name"]);
    this.set("textFilterCallback", () => {});

    await render(
      <template>
        <DFilterControls
          @array={{this.data}}
          @onTextFilterChange={{this.textFilterCallback}}
          @searchableProps={{this.searchableProps}}
        >
          <:content as |filteredData|>
            <div class="results">
              {{#each filteredData as |item|}}
                <div class="item" data-id={{item.id}}>{{item.name}}</div>
              {{/each}}
            </div>
          </:content>
        </DFilterControls>
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
    this.set("data", SAMPLE_DATA);

    await render(
      <template>
        <DFilterControls @array={{this.data}}>
          <:actions>
            <button class="custom-action" type="button">Custom Action</button>
          </:actions>
          <:content as |filteredData|>
            <div class="results">
              {{#each filteredData as |item|}}
                <div class="item">{{item.name}}</div>
              {{/each}}
            </div>
          </:content>
        </DFilterControls>
      </template>
    );

    assert
      .dom(".custom-action")
      .exists("renders custom actions in actions block");
  });

  test("yields to aboveContent block", async function (assert) {
    this.set("data", SAMPLE_DATA);

    await render(
      <template>
        <DFilterControls @array={{this.data}}>
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
        </DFilterControls>
      </template>
    );

    assert
      .dom(".above-content")
      .exists("renders content in aboveContent block");
  });

  test("shows custom no results message", async function (assert) {
    this.set("data", SAMPLE_DATA);
    this.set("searchableProps", ["name"]);

    await render(
      <template>
        <DFilterControls
          @array={{this.data}}
          @noResultsMessage="No items found matching your criteria"
          @searchableProps={{this.searchableProps}}
        >
          <:content as |filteredData|>
            <div class="results">
              {{#each filteredData as |item|}}
                <div class="item">{{item.name}}</div>
              {{/each}}
            </div>
          </:content>
        </DFilterControls>
      </template>
    );

    await fillIn(".filter-input", "nonexistent");

    assert
      .dom(".d-filter-controls__no-results p")
      .hasText(
        "No items found matching your criteria",
        "shows custom no results message"
      );
  });

  test("does not show dropdown filter when only one option", async function (assert) {
    this.set("data", SAMPLE_DATA);
    this.set("dropdownOptions", [{ label: "All", value: "all" }]);

    await render(
      <template>
        <DFilterControls
          @array={{this.data}}
          @dropdownOptions={{this.dropdownOptions}}
        >
          <:content as |filteredData|>
            <div class="results">
              {{#each filteredData as |item|}}
                <div class="item">{{item.name}}</div>
              {{/each}}
            </div>
          </:content>
        </DFilterControls>
      </template>
    );

    assert
      .dom(".d-filter-controls__dropdown")
      .doesNotExist("hides dropdown when only one option");
  });

  test("renders multiple dropdowns", async function (assert) {
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
        <DFilterControls
          @array={{this.data}}
          @dropdownOptions={{this.dropdownOptions}}
        >
          <:content as |filteredData|>
            <div class="results">
              {{#each filteredData as |item|}}
                <div class="item">{{item.name}}</div>
              {{/each}}
            </div>
          </:content>
        </DFilterControls>
      </template>
    );

    assert
      .dom(".d-filter-controls")
      .hasClass(
        "--dropdowns-in-filter-drawer",
        "uses the filter drawer layout"
      );
    assert
      .dom(".d-filter-controls__dropdown")
      .exists({ count: 2 }, "renders two dropdowns");
    assert
      .dom(".d-filter-controls__dropdown--category")
      .exists("renders category dropdown");
    assert
      .dom(".d-filter-controls__dropdown--enabled")
      .exists("renders enabled dropdown");
  });

  test("filters data by multiple dropdowns (client-side)", async function (assert) {
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
        <DFilterControls
          @array={{this.data}}
          @dropdownOptions={{this.dropdownOptions}}
        >
          <:content as |filteredData|>
            <div class="results">
              {{#each filteredData as |item|}}
                <div class="item" data-id={{item.id}}>{{item.name}}</div>
              {{/each}}
            </div>
          </:content>
        </DFilterControls>
      </template>
    );

    assert.dom(".item").exists({ count: 3 }, "shows all items initially");

    await select(".d-filter-controls__dropdown--category", "feature");

    assert
      .dom(".item")
      .exists({ count: 2 }, "shows only feature items after category filter");

    await select(".d-filter-controls__dropdown--enabled", "enabled");

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
        <DFilterControls
          @array={{this.data}}
          @dropdownOptions={{this.dropdownOptions}}
          @searchableProps={{this.searchableProps}}
        >
          <:content as |filteredData|>
            <div class="results">
              {{#each filteredData as |item|}}
                <div class="item" data-id={{item.id}}>{{item.name}}</div>
              {{/each}}
            </div>
          </:content>
        </DFilterControls>
      </template>
    );

    await select(".d-filter-controls__dropdown--category", "feature");
    await fillIn(".filter-input", "first");

    assert.dom(".item").exists({ count: 1 }, "shows filtered results");

    await fillIn(".filter-input", "firstblah");
    await click(".d-filter-controls__reset");

    assert.dom(".item").exists({ count: 3 }, "shows all items after reset");
  });

  test("calls onDropdownFilterChange with key and value for multiple dropdowns", async function (assert) {
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
        <DFilterControls
          @array={{this.data}}
          @dropdownOptions={{this.dropdownOptions}}
          @onDropdownFilterChange={{this.dropdownFilterCallback}}
        >
          <:content as |filteredData|>
            <div class="results">
              {{#each filteredData as |item|}}
                <div class="item">{{item.name}}</div>
              {{/each}}
            </div>
          </:content>
        </DFilterControls>
      </template>
    );

    await select(".d-filter-controls__dropdown--category", "feature");
    await select(".d-filter-controls__dropdown--enabled", "enabled");

    assert.verifySteps(
      ["dropdown-filter:category:feature", "dropdown-filter:enabled:enabled"],
      "calls callback with key and value for each dropdown"
    );
  });

  test("supports custom default values for multiple dropdowns", async function (assert) {
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
        <DFilterControls
          @array={{this.data}}
          @defaultDropdownValue={{this.defaultDropdownValue}}
          @dropdownOptions={{this.dropdownOptions}}
        >
          <:content as |filteredData|>
            <div class="results">
              {{#each filteredData as |item|}}
                <div class="item" data-id={{item.id}}>{{item.name}}</div>
              {{/each}}
            </div>
          </:content>
        </DFilterControls>
      </template>
    );

    assert
      .dom(".item")
      .exists(
        { count: 2 },
        "shows only feature items initially because of defaultDropdownValue"
      );

    await select(".d-filter-controls__dropdown--category", "all");

    assert
      .dom(".item")
      .exists({ count: 3 }, "shows all items after changing filter");
  });

  test("query param sync args are inert without a live router", async function (assert) {
    // outside a real route (router.currentURL is null, as in rendering
    // tests) the query param args must neither crash nor affect filtering
    this.set("data", SAMPLE_DATA);
    this.set("searchableProps", ["name"]);
    this.set("dropdownOptions", SAMPLE_DROPDOWN_OPTIONS);

    await render(
      <template>
        <DFilterControls
          @array={{this.data}}
          @dropdownFilterQueryParam="category"
          @dropdownOptions={{this.dropdownOptions}}
          @searchableProps={{this.searchableProps}}
          @textFilterQueryParam="filter"
        >
          <:content as |filteredData|>
            <div class="results">
              {{#each filteredData as |item|}}
                <div class="item" data-id={{item.id}}>{{item.name}}</div>
              {{/each}}
            </div>
          </:content>
        </DFilterControls>
      </template>
    );

    assert.dom(".item").exists({ count: 3 }, "renders all items");

    await fillIn(".d-filter-controls__input", "second");
    assert.dom(".item").exists({ count: 1 }, "text filtering still works");

    await select(".d-filter-controls__dropdown", "feature");
    assert
      .dom(".item")
      .doesNotExist("dropdown filtering still combines with text");

    await click(".d-filter-controls__reset");
    assert.dom(".item").exists({ count: 3 }, "reset still works");
  });

  test("initialTextFilter still seeds when a query param arg is set", async function (assert) {
    this.set("data", SAMPLE_DATA);
    this.set("searchableProps", ["name"]);

    await render(
      <template>
        <DFilterControls
          @array={{this.data}}
          @initialTextFilter="third"
          @searchableProps={{this.searchableProps}}
          @textFilterQueryParam="filter"
        >
          <:content as |filteredData|>
            <div class="results">
              {{#each filteredData as |item|}}
                <div class="item" data-id={{item.id}}>{{item.name}}</div>
              {{/each}}
            </div>
          </:content>
        </DFilterControls>
      </template>
    );

    assert.dom(".d-filter-controls__input").hasValue("third");
    assert.dom(".item").exists({ count: 1 }, "applies the seeded filter");
  });

  test("reveals a URL-owned dropdown activated by a route change", async function (assert) {
    this.owner.unregister("service:router");
    this.owner.register("service:router", RouterStub);

    this.set("data", SAMPLE_DATA);
    this.set("dropdownOptions", {
      category: SAMPLE_DROPDOWN_OPTIONS,
    });
    this.set("dropdownFilterQueryParams", { category: "category" });

    await render(
      <template>
        <DFilterControls
          @array={{this.data}}
          @dropdownFilterQueryParams={{this.dropdownFilterQueryParams}}
          @dropdownOptions={{this.dropdownOptions}}
          @filterDropdownsExpanded={{false}}
        >
          <:content as |filteredData|>
            <div class="results">
              {{#each filteredData as |item|}}
                <div class="item" data-id={{item.id}}>{{item.name}}</div>
              {{/each}}
            </div>
          </:content>
        </DFilterControls>
      </template>
    );

    assert
      .dom(".d-filter-controls__dropdown--category")
      .doesNotExist("keeps inactive dropdown filters collapsed initially");

    this.owner
      .lookup("service:router")
      .changeURL("/admin/example?category=feature");
    await settled();

    assert
      .dom(".d-filter-controls__dropdown--category")
      .hasValue("feature", "reveals the URL-owned active dropdown");
    assert
      .dom(".item")
      .exists({ count: 2 }, "applies the dropdown filter from the new URL");
  });

  test("shows a custom empty state in a yield when showEmptyState is true and the array is empty", async function (assert) {
    this.set("data", []);

    await render(
      <template>
        <DFilterControls
          @array={{this.data}}
          @minItemsForFilter={{1}}
          @showCustomEmptyState={{true}}
        >
          <:content>
            N/A
          </:content>
          <:customEmptyState>
            <div class="custom-empty-state">Custom Empty State</div>
          </:customEmptyState>
        </DFilterControls>
      </template>
    );

    assert
      .dom(".custom-empty-state")
      .exists("renders the custom empty state when array is empty");
  });

  test("reports the drawer state when the filter toggle is used", async function (assert) {
    this.set("data", SAMPLE_DATA);
    this.set("dropdownOptions", {
      category: SAMPLE_DROPDOWN_OPTIONS,
    });
    const states = [];
    this.set("onToggle", (expanded) => states.push(expanded));

    await render(
      <template>
        <DFilterControls
          @array={{this.data}}
          @dropdownOptions={{this.dropdownOptions}}
          @filterDropdownsExpanded={{false}}
          @forceShowDropdownFilterToggle={{true}}
          @onFilterDropdownsToggle={{this.onToggle}}
        />
      </template>
    );

    await click(".d-filter-controls__toggle-filters");
    await click(".d-filter-controls__toggle-filters");

    assert.deepEqual(
      states,
      [true, false],
      "each toggle reports the resulting expanded state"
    );
  });
});
