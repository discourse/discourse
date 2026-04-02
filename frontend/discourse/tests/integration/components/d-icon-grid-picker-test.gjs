import { click, render, triggerKeyEvent, waitFor } from "@ember/test-helpers";
import { module, test } from "qunit";
import DIconGridPicker from "discourse/components/d-icon-grid-picker";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

const noop = () => {};

function iconFixtures(ids) {
  return ids.map((id) => ({ id, symbol: `<symbol id="${id}"></symbol>` }));
}

module("Integration | Component | DIconGridPicker", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    pretender.get("/svg-sprite/picker-search", (request) => {
      const filter = request.queryParams.filter || "";

      if (filter === "no-match-xyz") {
        return response(200, []);
      }

      const allIcons = iconFixtures([
        "pencil",
        "trash-can",
        "gear",
        "heart",
        "star",
      ]);

      if (filter) {
        return response(
          200,
          allIcons.filter((i) => i.id.includes(filter))
        );
      }

      return response(200, allIcons);
    });
  });

  test("renders trigger with selected icon", async function (assert) {
    await render(
      <template>
        <DIconGridPicker @value="pencil" @onChange={{noop}} />
      </template>
    );

    assert
      .dom(".d-icon-grid-picker-trigger .d-icon-pencil")
      .exists("shows the selected icon in the trigger");
  });

  test("clears the selected icon when clear button is clicked", async function (assert) {
    let currentValue = "pencil";
    const onChange = (val) => (currentValue = val);

    await render(
      <template>
        <DIconGridPicker
          @value={{currentValue}}
          @onChange={{onChange}}
          @allowClear={{true}}
        />
      </template>
    );

    assert.dom(".d-icon-grid-picker__clear").exists();
    await click(".d-icon-grid-picker__clear");
    assert.strictEqual(currentValue, null);
  });

  test("does not show clear button when allowClear is false", async function (assert) {
    await render(
      <template>
        <DIconGridPicker @value="pencil" @onChange={{noop}} />
      </template>
    );

    assert.dom(".d-icon-grid-picker__clear").doesNotExist();
  });

  test("does not show clear button when no value", async function (assert) {
    await render(
      <template>
        <DIconGridPicker
          @value={{null}}
          @onChange={{noop}}
          @allowClear={{true}}
        />
      </template>
    );

    assert.dom(".d-icon-grid-picker__clear").doesNotExist();
  });

  test("renders trigger with no icon when no value", async function (assert) {
    await render(
      <template>
        <DIconGridPicker @value={{null}} @onChange={{noop}} />
      </template>
    );

    assert
      .dom(".d-icon-grid-picker-trigger .d-icon")
      .doesNotExist("shows no icon when value is empty");
  });

  test("displays icons in the grid after opening", async function (assert) {
    await render(
      <template>
        <DIconGridPicker @value={{null}} @onChange={{noop}} />
      </template>
    );

    await click(".d-icon-grid-picker-trigger");
    await waitFor(".d-icon-grid-picker__icon");

    assert
      .dom(".d-icon-grid-picker__grid .d-icon-grid-picker__icon")
      .exists({ count: 5 }, "renders all fetched icons");
  });

  test("calls @onChange when an icon is selected", async function (assert) {
    let selectedIcon;
    const onChange = (iconId) => (selectedIcon = iconId);

    await render(
      <template>
        <DIconGridPicker @value={{null}} @onChange={{onChange}} />
      </template>
    );

    await click(".d-icon-grid-picker-trigger");
    await waitFor(".d-icon-grid-picker__icon");
    await click('[data-icon-id="gear"]');

    assert.strictEqual(selectedIcon, "gear", "onChange receives the icon ID");
  });

  test("displays favorites row when @favorites is provided", async function (assert) {
    const favorites = ["heart", "star"];

    await render(
      <template>
        <DIconGridPicker
          @value="heart"
          @onChange={{noop}}
          @favorites={{favorites}}
        />
      </template>
    );

    await click(".d-icon-grid-picker-trigger");
    await waitFor(".d-icon-grid-picker__favorites");

    assert
      .dom(".d-icon-grid-picker__favorites .d-icon-grid-picker__icon")
      .exists({ count: 2 }, "shows the selected icon and favorites");
  });

  test("selected icon has --selected class in favorites", async function (assert) {
    const favorites = ["star"];

    await render(
      <template>
        <DIconGridPicker
          @value="heart"
          @onChange={{noop}}
          @favorites={{favorites}}
        />
      </template>
    );

    await click(".d-icon-grid-picker-trigger");
    await waitFor(".d-icon-grid-picker__favorites");

    assert
      .dom('.d-icon-grid-picker__favorites [data-icon-id="heart"]')
      .hasClass(
        "--selected",
        "selected icon in favorites has --selected class"
      );
    assert
      .dom('.d-icon-grid-picker__favorites [data-icon-id="star"]')
      .doesNotHaveClass(
        "--selected",
        "non-selected favorite does not have --selected class"
      );
  });

  test("shows selected name when @showSelectedName is true", async function (assert) {
    await render(
      <template>
        <DIconGridPicker
          @value="heart"
          @onChange={{noop}}
          @showSelectedName={{true}}
        />
      </template>
    );

    await click(".d-icon-grid-picker-trigger");
    await waitFor(".d-icon-grid-picker__favorites");

    assert
      .dom(
        ".d-icon-grid-picker__selected-chip .d-icon-grid-picker__selected-name"
      )
      .hasText("heart", "displays the icon name in the selected chip");
  });

  test("shows empty state when no icons match", async function (assert) {
    await render(
      <template>
        <DIconGridPicker @value={{null}} @onChange={{noop}} />
      </template>
    );

    await click(".d-icon-grid-picker-trigger");
    await waitFor(".d-icon-grid-picker__icon");

    const input = document.querySelector(
      ".d-icon-grid-picker__filter .filter-input"
    );
    await fillInFilterInput(input, "no-match-xyz");

    await waitFor(".d-icon-grid-picker__empty");

    assert
      .dom(".d-icon-grid-picker__empty")
      .exists("shows the empty state message");
  });

  test("shows caret icon when @showCaret is true", async function (assert) {
    await render(
      <template>
        <DIconGridPicker
          @value="pencil"
          @onChange={{noop}}
          @showCaret={{true}}
        />
      </template>
    );

    assert
      .dom(".d-icon-grid-picker-trigger .d-icon-grid-picker__caret")
      .exists("shows caret icon");
  });

  test("does not show caret icon by default", async function (assert) {
    await render(
      <template>
        <DIconGridPicker @value="pencil" @onChange={{noop}} />
      </template>
    );

    assert
      .dom(".d-icon-grid-picker-trigger .d-icon-grid-picker__caret")
      .doesNotExist("caret is hidden by default");
  });

  test("disables trigger when @disabled is true", async function (assert) {
    await render(
      <template>
        <DIconGridPicker
          @value="pencil"
          @onChange={{noop}}
          @disabled={{true}}
        />
      </template>
    );

    assert.dom(".d-icon-grid-picker-trigger").isDisabled();
  });

  test("shows default label when no value", async function (assert) {
    await render(
      <template>
        <DIconGridPicker @value={{null}} @onChange={{noop}} />
      </template>
    );

    assert
      .dom(".d-icon-grid-picker-trigger .d-icon-grid-picker__label")
      .exists("shows label when no value");
  });

  test("shows custom label", async function (assert) {
    await render(
      <template>
        <DIconGridPicker @value={{null}} @onChange={{noop}} @label="Pick one" />
      </template>
    );

    assert
      .dom(".d-icon-grid-picker-trigger .d-icon-grid-picker__label")
      .hasText("Pick one");
  });

  test("hides label when value is set and no explicit label", async function (assert) {
    await render(
      <template>
        <DIconGridPicker @value="pencil" @onChange={{noop}} />
      </template>
    );

    assert
      .dom(".d-icon-grid-picker-trigger .d-icon-grid-picker__label")
      .doesNotExist("label hidden when icon is selected");
  });

  test("applies default btn-default class to trigger", async function (assert) {
    await render(
      <template>
        <DIconGridPicker @value={{null}} @onChange={{noop}} />
      </template>
    );

    assert.dom(".d-icon-grid-picker-trigger").hasClass("btn-default");
  });

  test("applies custom @btnClass to trigger", async function (assert) {
    await render(
      <template>
        <DIconGridPicker
          @value={{null}}
          @onChange={{noop}}
          @btnClass="btn-primary"
        />
      </template>
    );

    assert.dom(".d-icon-grid-picker-trigger").hasClass("btn-primary");
    assert.dom(".d-icon-grid-picker-trigger").doesNotHaveClass("btn-default");
  });

  test("sets --icon-color CSS variable when @iconColor is provided", async function (assert) {
    await render(
      <template>
        <DIconGridPicker
          @value="pencil"
          @onChange={{noop}}
          @iconColor="#FF0000"
        />
      </template>
    );

    const wrapper = document.querySelector(".d-icon-grid-picker");
    assert.true(
      wrapper.style.cssText.includes("--icon-color: #FF0000"),
      "sets --icon-color custom property"
    );
  });

  test("does not set --icon-color when @iconColor is not provided", async function (assert) {
    await render(
      <template>
        <DIconGridPicker @value="pencil" @onChange={{noop}} />
      </template>
    );

    const wrapper = document.querySelector(".d-icon-grid-picker");
    assert.false(
      wrapper.style.cssText.includes("--icon-color"),
      "no --icon-color custom property"
    );
  });

  test("sets data-value attribute", async function (assert) {
    await render(
      <template>
        <DIconGridPicker @value="pencil" @onChange={{noop}} />
      </template>
    );

    assert.dom(".d-icon-grid-picker").hasAttribute("data-value", "pencil");
  });

  test("sets title on trigger when value is selected", async function (assert) {
    await render(
      <template>
        <DIconGridPicker @value="pencil" @onChange={{noop}} />
      </template>
    );

    assert.dom(".d-icon-grid-picker-trigger").hasAttribute("title");
  });

  test("fires @onShow callback when menu opens", async function (assert) {
    let showCalled = false;
    const onShow = () => (showCalled = true);

    await render(
      <template>
        <DIconGridPicker
          @value={{null}}
          @onChange={{noop}}
          @onShow={{onShow}}
        />
      </template>
    );

    await click(".d-icon-grid-picker-trigger");
    assert.true(showCalled, "onShow was called");
  });

  test("fires @onClose callback when menu closes", async function (assert) {
    let closeCalled = false;
    const onClose = () => (closeCalled = true);

    await render(
      <template>
        <DIconGridPicker
          @value={{null}}
          @onChange={{noop}}
          @onClose={{onClose}}
        />
      </template>
    );

    await click(".d-icon-grid-picker-trigger");
    await waitFor(".d-icon-grid-picker__icon");
    await click(".d-icon-grid-picker-trigger");
    assert.true(closeCalled, "onClose was called");
  });

  test("grid wrapper has listbox role", async function (assert) {
    await render(
      <template>
        <DIconGridPicker @value={{null}} @onChange={{noop}} />
      </template>
    );

    await click(".d-icon-grid-picker-trigger");
    await waitFor(".d-icon-grid-picker__icon");

    assert
      .dom(".d-icon-grid-picker__grid-wrapper")
      .hasAttribute("role", "listbox");
  });

  test("icon buttons have option role and aria-selected on selected icon", async function (assert) {
    await render(
      <template><DIconGridPicker @value="gear" @onChange={{noop}} /></template>
    );

    await click(".d-icon-grid-picker-trigger");
    await waitFor(".d-icon-grid-picker__icon");

    assert
      .dom('[data-icon-id="gear"]')
      .hasAttribute("role", "option")
      .hasAttribute("aria-selected", "true");

    assert
      .dom('[data-icon-id="pencil"]')
      .hasAttribute("role", "option")
      .hasAttribute("aria-selected", "false");
  });

  test("arrow keys navigate between icons", async function (assert) {
    await render(
      <template>
        <DIconGridPicker @value={{null}} @onChange={{noop}} />
      </template>
    );

    await click(".d-icon-grid-picker-trigger");
    await waitFor(".d-icon-grid-picker__icon");

    const firstIcon = document.querySelector(".d-icon-grid-picker__icon");
    firstIcon.focus();

    await triggerKeyEvent(firstIcon, "keydown", "ArrowRight");
    assert
      .dom(document.activeElement)
      .hasAttribute("data-icon-id", "trash-can");

    await triggerKeyEvent(document.activeElement, "keydown", "ArrowLeft");
    assert.dom(document.activeElement).hasAttribute("data-icon-id", "pencil");
  });

  test("ArrowDown from filter focuses first icon", async function (assert) {
    await render(
      <template>
        <DIconGridPicker @value={{null}} @onChange={{noop}} />
      </template>
    );

    await click(".d-icon-grid-picker-trigger");
    await waitFor(".d-icon-grid-picker__icon");

    const filterInput = document.querySelector(
      ".d-icon-grid-picker__filter .filter-input"
    );
    filterInput.focus();

    await triggerKeyEvent(filterInput, "keydown", "ArrowDown");
    assert.true(
      document.activeElement.classList.contains("d-icon-grid-picker__icon"),
      "first icon is focused"
    );
  });

  test("ArrowUp from first icon focuses filter", async function (assert) {
    await render(
      <template>
        <DIconGridPicker @value={{null}} @onChange={{noop}} />
      </template>
    );

    await click(".d-icon-grid-picker-trigger");
    await waitFor(".d-icon-grid-picker__icon");

    const firstIcon = document.querySelector(".d-icon-grid-picker__icon");
    firstIcon.focus();

    await triggerKeyEvent(firstIcon, "keydown", "ArrowUp");
    assert.true(
      document.activeElement.classList.contains("filter-input"),
      "filter input is focused"
    );
  });

  test("rejects invalid @iconColor values", async function (assert) {
    await render(
      <template>
        <DIconGridPicker
          @value="pencil"
          @onChange={{noop}}
          @iconColor="red; background: url(evil)"
        />
      </template>
    );

    const wrapper = document.querySelector(".d-icon-grid-picker");
    assert.false(
      wrapper.style.cssText.includes("--icon-color"),
      "does not set --icon-color for invalid value"
    );
  });

  test("hides favorites row while filtering", async function (assert) {
    const favorites = ["heart"];

    await render(
      <template>
        <DIconGridPicker
          @value="heart"
          @onChange={{noop}}
          @favorites={{favorites}}
        />
      </template>
    );

    await click(".d-icon-grid-picker-trigger");
    await waitFor(".d-icon-grid-picker__favorites");

    assert
      .dom(".d-icon-grid-picker__favorites")
      .exists("favorites visible initially");

    const input = document.querySelector(
      ".d-icon-grid-picker__filter .filter-input"
    );
    await fillInFilterInput(input, "gear");

    assert
      .dom(".d-icon-grid-picker__favorites")
      .doesNotExist("favorites hidden while filtering");
  });
});

async function fillInFilterInput(input, value) {
  input.value = value;
  input.dispatchEvent(new Event("input", { bubbles: true }));
  // Wait for debounced async content to resolve
  await new Promise((resolve) => setTimeout(resolve, 300));
  await waitFor(".d-icon-grid-picker__icon, .d-icon-grid-picker__empty");
}
