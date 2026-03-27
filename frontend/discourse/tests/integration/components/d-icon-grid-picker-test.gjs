import { click, render, waitFor } from "@ember/test-helpers";
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

  test("renders trigger with placeholder when no value", async function (assert) {
    await render(
      <template>
        <DIconGridPicker @value={{null}} @onChange={{noop}} />
      </template>
    );

    assert
      .dom(".d-icon-grid-picker-trigger .d-icon-question")
      .exists("shows the question icon as placeholder");
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
