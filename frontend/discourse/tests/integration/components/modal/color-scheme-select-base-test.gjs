import { array, hash } from "@ember/helper";
import { click, findAll, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import ColorSchemeSelectBase from "discourse/admin/components/modal/color-scheme-select-base";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dSelect from "discourse/tests/helpers/d-select-helper";

const FIELD = ".select-base-palette[data-trigger]";

const PALETTES = [
  { id: -3, name: "Neutral", is_dark: false, colors: [] },
  { id: -4, name: "Grey Amber", is_dark: true, colors: [] },
  { id: 16, name: "Dracula", is_dark: true, colors: [] },
  { id: 17, name: "Solarized Light", is_dark: false, colors: [] },
];

module(
  "Integration | Component | Modal | color-scheme-select-base",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.siteSettings.enable_new_select_controls = true;
    });

    test("picks the base palette with the new select, marking the site's palettes", async function (assert) {
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

      assert.dSelect(FIELD).hasName("Neutral", "the first palette is held");

      const select = dSelect(FIELD);
      await select.open();

      assert.deepEqual(
        findAll(".d-select__group-header").map((h) => h.textContent.trim()),
        ["Light", "Dark"]
      );
      assert
        .dom("[role='option'][data-value='17'] .d-select__option-description")
        .hasText("Active");
      assert
        .dom("[role='option'][data-value='16'] .d-select__option-description")
        .hasText("Active");
      assert
        .dom("[role='option'][data-value='-3'] .d-select__option-description")
        .doesNotExist("the held base isn't in use");

      await select.select(-4);
      await click(".create-color-palette .btn-primary");

      assert.deepEqual(bases, [-4]);
    });
  }
);
