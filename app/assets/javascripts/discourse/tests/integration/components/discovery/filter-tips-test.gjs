import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import {
  fillIn,
  render,
  triggerEvent,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import FilterTips from "discourse/components/discovery/filter-tips";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

module("Integration | Component | discovery | filter-tips", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.tips = [
      {
        name: "category:",
        description: "Filter category",
        priority: 1,
        type: "category",
      },
      {
        name: "tag:",
        description: "Filter tag",
        priority: 1,
        type: "tag",
        delimiters: [
          { name: "+", description: "intersect" },
          { name: ",", description: "add" },
        ],
      },
      { name: "status:", description: "Filter status", priority: 1 },
      { name: "status:open", description: "Open topics" },
    ];
    this.query = "";
    this.update = (value) => {
      this.set("query", value);
      this.inputElement.value = value;
    };
    this.blockEnter = () => {};
    this.capture = (el) => (this.inputElement = el);

    this.site.categories = [
      { id: 1, name: "Bug", slug: "bugs" },
      { id: 2, name: "Feature", slug: "feature" },
    ];
    pretender.get("/tags/filter/search.json", () =>
      response({ results: [{ name: "ember", count: 1 }] })
    );
    pretender.get("/u/search/users", () => response({ users: [] }));
  });

  test("basic navigation", async function (assert) {
    const self = this;
    await render(
      <template>
        <input id="filter-input" {{didInsert self.capture}} />
        <FilterTips
          @tips={{self.tips}}
          @queryString={{self.query}}
          @onSelectTip={{self.update}}
          @blockEnterSubmit={{self.blockEnter}}
          @inputElement={{self.inputElement}}
        />
      </template>
    );

    await triggerEvent("#filter-input", "focus");
    assert
      .dom(".filter-tip__button")
      .exists({ count: 3 }, "shows tips on focus");
    assert
      .dom(".filter-tip__button.filter-tip__selected")
      .doesNotExist("no selection yet");
    assert.dom("#filter-input").hasValue("");

    await triggerKeyEvent("#filter-input", "keydown", "ArrowDown");
    assert
      .dom(".filter-tip__button.filter-tip__selected .filter-tip__name")
      .hasText("category:");

    await triggerKeyEvent("#filter-input", "keydown", "ArrowDown");
    assert
      .dom(".filter-tip__button.filter-tip__selected .filter-tip__name")
      .hasText("tag:");

    await triggerKeyEvent("#filter-input", "keydown", "ArrowUp");
    assert
      .dom(".filter-tip__button.filter-tip__selected .filter-tip__name")
      .hasText("category:");
  });

  test("selecting a tip with tab", async function (assert) {
    const self = this;
    await render(
      <template>
        <input id="filter-input" {{didInsert self.capture}} />
        <FilterTips
          @tips={{self.tips}}
          @queryString={{self.query}}
          @onSelectTip={{self.update}}
          @blockEnterSubmit={{self.blockEnter}}
          @inputElement={{self.inputElement}}
        />
      </template>
    );

    await triggerEvent("#filter-input", "focus");
    await triggerKeyEvent("#filter-input", "keydown", "ArrowDown");
    await triggerKeyEvent("#filter-input", "keydown", "Tab");

    assert.strictEqual(this.query, "category:", "tab adds filter");
    assert.dom("#filter-input").hasValue("category:");

    assert
      .dom(".filter-tip__button")
      .exists({ count: 2 }, "tips for category shows up");

    await triggerEvent("#filter-input", "focus");
    await triggerKeyEvent("#filter-input", "keydown", "Tab");

    assert
      .dom("#filter-input")
      .hasValue("category:bugs ", "category slug added");

    assert
      .dom(".filter-tip__button")
      .exists({ count: 3 }, "tips for next section shows up");
    assert
      .dom(".filter-tip__button.selected")
      .doesNotExist("selection cleared");
  });

  test("searching tag values", async function (assert) {
    const self = this;
    await render(
      <template>
        <input id="filter-input" {{didInsert self.capture}} />
        <FilterTips
          @tips={{self.tips}}
          @queryString={{self.query}}
          @onSelectTip={{self.update}}
          @blockEnterSubmit={{self.blockEnter}}
          @inputElement={{self.inputElement}}
        />
      </template>
    );

    await triggerEvent("#filter-input", "focus");
    await fillIn("#filter-input", "tag:e");

    assert.dom(".filter-tip__button").exists("shows tag results");
    assert.dom(".filter-tip__name").hasText("tag:ember");
    assert.dom(".filter-tip__description").hasText("— 1");

    await triggerKeyEvent("#filter-input", "keydown", "ArrowDown");
    assert
      .dom(".filter-tip__button.filter-tip__selected .filter-tip__name")
      .hasText("tag:ember");

    await triggerKeyEvent("#filter-input", "keydown", "Enter");
    assert.strictEqual(this.query, "tag:ember", "enter selects result");
  });

  test("escape hides suggestions", async function (assert) {
    const self = this;
    await render(
      <template>
        <input id="filter-input" {{didInsert self.capture}} />
        <FilterTips
          @tips={{self.tips}}
          @queryString={{self.query}}
          @onSelectTip={{self.update}}
          @blockEnterSubmit={{self.blockEnter}}
          @inputElement={{self.inputElement}}
        />
      </template>
    );

    await triggerEvent("#filter-input", "focus");
    assert.dom(".filter-tip__button").exists("tips visible");
    await triggerKeyEvent("#filter-input", "keydown", "Escape");
    assert.dom(".filter-tip__button").doesNotExist("tips hidden on escape");

    await fillIn("#filter-input", "status");
    await triggerEvent("#filter-input", "input");
    await triggerKeyEvent("#filter-input", "keydown", "Escape");
    assert.strictEqual(this.query, "", "query not changed");
    assert.dom("#filter-input").hasValue("status", "input unchanged");
    assert.dom(".filter-tip__button").doesNotExist("tips remain hidden");
  });

  test("blockEnterSubmit is called correctly", async function (assert) {
    let blockEnterCalled = false;
    let blockEnterValue = null;

    this.blockEnter = (shouldBlock) => {
      blockEnterCalled = true;
      blockEnterValue = shouldBlock;
    };

    let self = this;

    await render(
      <template>
        <input id="filter-input" {{didInsert self.capture}} />
        <FilterTips
          @tips={{self.tips}}
          @queryString={{self.query}}
          @onSelectTip={{self.update}}
          @blockEnterSubmit={{self.blockEnter}}
          @inputElement={{self.inputElement}}
        />
      </template>
    );

    // Initially, no selection, so blockEnter should be called with false
    await triggerEvent("#filter-input", "focus");
    assert.true(blockEnterCalled, "blockEnter was called");
    assert.false(
      blockEnterValue,
      "blockEnter called with false when no selection"
    );

    // Reset tracking
    blockEnterCalled = false;
    blockEnterValue = null;

    // Arrow down to select first item
    await triggerKeyEvent("#filter-input", "keydown", "ArrowDown");
    assert.true(blockEnterCalled, "blockEnter called when selection changes");
    assert.true(
      blockEnterValue,
      "blockEnter called with true when item selected"
    );

    // Reset and arrow up to wrap to last item
    blockEnterCalled = false;
    await triggerKeyEvent("#filter-input", "keydown", "ArrowUp");
    await triggerKeyEvent("#filter-input", "keydown", "ArrowUp");
    assert.true(blockEnterCalled, "blockEnter called on arrow navigation");
    assert.true(blockEnterValue, "blockEnter still true with selection");

    // Select an item with Tab
    await triggerKeyEvent("#filter-input", "keydown", "Tab");
    assert.true(blockEnterCalled, "blockEnter called after selection");
    assert.false(
      blockEnterValue,
      "blockEnter called with false after selecting"
    );

    // Type to trigger search for tag values
    await fillIn("#filter-input", "tag:e");
    assert.true(blockEnterCalled, "blockEnter called when typing");
    assert.false(blockEnterValue, "blockEnter false when typing");

    // Select a search result
    await triggerKeyEvent("#filter-input", "keydown", "ArrowDown");
    assert.true(blockEnterValue, "blockEnter true when search result selected");

    // Escape to clear
    await triggerKeyEvent("#filter-input", "keydown", "Escape");
    assert.false(blockEnterValue, "blockEnter false after escape");
  });

  test("prefix support for categories", async function (assert) {
    // Add prefix data to tips
    this.tips = [
      {
        name: "category:",
        description: "Filter category",
        priority: 1,
        type: "category",
        prefixes: [
          { name: "-", description: "Exclude category" },
          { name: "=", description: "Category without subcategories" },
        ],
      },
      { name: "tag:", description: "Filter tag", priority: 1, type: "tag" },
    ];

    const self = this;
    await render(
      <template>
        <input id="filter-input" {{didInsert self.capture}} />
        <FilterTips
          @tips={{self.tips}}
          @queryString={{self.query}}
          @onSelectTip={{self.update}}
          @blockEnterSubmit={{self.blockEnter}}
          @inputElement={{self.inputElement}}
        />
      </template>
    );

    await triggerEvent("#filter-input", "focus");
    await fillIn("#filter-input", "cat");

    const buttons = document.querySelectorAll(".filter-tip__button");
    const lastButton = buttons[buttons.length - 1];

    assert.dom(lastButton).exists("shows filtered results");
    assert
      .dom(lastButton.querySelector(".filter-tip__name"))
      .hasText("=category:");
    assert
      .dom(lastButton.querySelector(".filter-tip__description"))
      .includesText("without", "shows prefix description");

    // we skip the "category" and go to negative prefix
    await triggerKeyEvent("#filter-input", "keydown", "ArrowDown");
    await triggerKeyEvent("#filter-input", "keydown", "ArrowDown");
    await triggerKeyEvent("#filter-input", "keydown", "Tab");

    assert.strictEqual(this.query, "-category:", "prefix included in query");
    assert.dom("#filter-input").hasValue("-category:");

    assert
      .dom(".filter-tip__button")
      .exists({ count: 2 }, "shows category options after prefix");
    assert
      .dom(".filter-tip__button:first-child .filter-tip__name")
      .hasText("-category:bugs", "shows category slug");

    // Select a category
    await triggerKeyEvent("#filter-input", "keydown", "Tab");
    assert
      .dom("#filter-input")
      .hasValue("-category:bugs ", "full filter with prefix applied");

    // Test with equals prefix
    await fillIn("#filter-input", "=cat");
    assert
      .dom(".filter-tip__description")
      .includesText(
        "Category without subcategories",
        "shows = prefix description"
      );

    await triggerKeyEvent("#filter-input", "keydown", "ArrowDown");
    await triggerKeyEvent("#filter-input", "keydown", "Tab");
    assert.strictEqual(this.query, "=category:", "equals prefix included");
  });
});
