import { array, hash } from "@ember/helper";
import { click, findAll, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import ColorSchemeSelectBase from "discourse/admin/components/modal/color-scheme-select-base";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dSelect from "discourse/tests/helpers/d-select-helper";

const LIST = ".select-base-palette";
const SUMMARY = ".select-base-summary";

const PALETTES = [
  { id: -3, name: "Neutral", is_dark: false, colors: [] },
  { id: -4, name: "Grey Amber", is_dark: true, colors: [] },
  { id: 16, name: "Dracula", is_dark: true, colors: [] },
  { id: 17, name: "Solarized Light", is_dark: false, colors: [] },
];

/** The palettes the list offers, by id, in order. */
function listed() {
  return findAll(`${LIST} [role='option']`).map((row) => row.dataset.value);
}

module(
  "Integration | Component | Modal | color-scheme-select-base",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.siteSettings.enable_new_select_controls = true;
    });

    test("shows the base apart from the other palettes, and creates from it", async function (assert) {
      const bases = [];
      const newColorSchemeWithBase = (id) => bases.push(id);
      const noop = () => {};

      await render(
        <template>
          <ColorSchemeSelectBase
            @closeModal={{noop}}
            @inline={{true}}
            @model={{hash
              activeColorSchemeIds=(array 17 16)
              colorSchemes=PALETTES
              newColorSchemeWithBase=newColorSchemeWithBase
            }}
          />
        </template>
      );

      assert.dom(".d-modal__title-text").hasText("New color palette");
      assert
        .dom(".select-base-intro")
        .hasText("Your new palette starts as a copy of this one.");
      assert.dom(".select-base-label").hasText("Other palettes");
      assert
        .dom(`${SUMMARY} .d-select-color-palette__name`)
        .hasText("Neutral", "the first palette is the base");
      assert
        .dom(`${SUMMARY} .d-select-color-palette__badge`)
        .doesNotExist("the base isn't in use");
      assert.dom(`${LIST} input`).hasAria("label", "Other palettes");
      assert.deepEqual(listed(), ["17", "-4", "16"], "the base isn't listed");
      assert.deepEqual(
        findAll(`${LIST} .d-select__group-header`).map((header) =>
          header.textContent.trim()
        ),
        ["Light", "Dark"],
        "the others are grouped by mode"
      );
      assert
        .dom(`${LIST} [data-value='17'] .d-select__option-description`)
        .hasText("Active");
      assert.dom(`${LIST} .d-select__chip`).doesNotExist("no chip repeats it");

      const select = dSelect(LIST);
      await select.select(-4);

      assert
        .dom(`${SUMMARY} .d-select-color-palette__name`)
        .hasText("Grey Amber", "the pick becomes the base");
      assert.deepEqual(
        listed(),
        ["-3", "17", "16"],
        "the previous base is listed again"
      );

      await select.search("solar");

      assert
        .dom(`${SUMMARY} .d-select-color-palette__name`)
        .hasText("Grey Amber", "a search leaves the base in view");

      assert
        .dom(".create-color-palette .btn-primary")
        .hasText("Create palette");
      await click(".create-color-palette .btn-primary");

      assert.deepEqual(bases, [-4]);
    });

    test("marks an in-use base as active", async function (assert) {
      const noop = () => {};

      await render(
        <template>
          <ColorSchemeSelectBase
            @closeModal={{noop}}
            @inline={{true}}
            @model={{hash
              activeColorSchemeIds=(array -3)
              colorSchemes=PALETTES
              newColorSchemeWithBase=noop
            }}
          />
        </template>
      );

      assert.dom(`${SUMMARY} .d-select-color-palette__badge`).hasText("Active");
    });
  }
);
