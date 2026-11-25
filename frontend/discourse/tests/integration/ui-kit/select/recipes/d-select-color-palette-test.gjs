import { tracked } from "@glimmer/tracking";
import { array, hash } from "@ember/helper";
import { find, findAll, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { DSelect } from "discourse/tests/helpers/d-select-helper";
import DSelectColorPalette from "discourse/ui-kit/select/recipes/color-palettes/d-select-color-palette";

/** A palette as the call sites pass it, with the colors its preview reads. */
function palette(id, name, isDark, tertiary) {
  return {
    id,
    name,
    is_dark: isDark,
    colors: [
      { name: "primary", hex: isDark ? "dddddd" : "222222" },
      { name: "secondary", hex: isDark ? "222222" : "ffffff" },
      { name: "tertiary", hex: tertiary },
    ],
  };
}

const DRACULA = palette(2, "Dracula", true, "bd93f9");
const SOLARIZED_LIGHT = palette(3, "Solarized Light", false, "268bd2");
const CLOVER = palette(4, "Clover", false, "2a8a4a");
const CLOVER_DARK = palette(5, "Clover Dark", true, "3bb36a");

/** A palette with every color its strip reads, and a header colored apart from its background. */
function fullPalette(id, name, { selected = "e8e6d3" } = {}) {
  return {
    id,
    name,
    is_dark: false,
    colors: [
      { name: "primary", hex: "073642" },
      { name: "secondary", hex: "fdf6e3" },
      { name: "tertiary", hex: "268bd2" },
      { name: "quaternary", default_hex: "cb4b16" },
      { name: "header_background", hex: "eee8d5" },
      { name: "highlight", hex: "ffff4d" },
      ...(selected ? [{ name: "selected", hex: selected }] : []),
    ],
  };
}

/** The colors of a strip's squares, as `rgb()` strings in order. */
function swatchColors(scope) {
  return findAll(`${scope} .d-select-color-palette__swatch`).map(
    (swatch) => getComputedStyle(swatch).backgroundColor
  );
}

function headings() {
  return findAll(".d-select__group-header").map((header) =>
    header.textContent.trim()
  );
}

function row(id) {
  return `[role='option'][data-value='${id}']`;
}

module(
  "Integration | ui-kit | select | recipes | DSelectColorPalette",
  function (hooks) {
    setupRenderingTest(hooks);

    test("color palettes: each row shows the palette's colors beside its name", async function (assert) {
      const palettes = [SOLARIZED_LIGHT, CLOVER];

      await render(
        <template>
          <DSelectColorPalette @palettes={{palettes}} @value={{3}} />
        </template>
      );
      await new DSelect().open();

      assert
        .dom(`${row(4)} .d-select-color-palette__preview`)
        .hasAttribute("style", /--tertiary--preview: #2a8a4a/);
      assert.dom(row(4)).includesText("Clover");
      assert
        .dom(".d-select__option-description")
        .doesNotExist("no palette is marked in use unless the caller says so");
    });

    test("color palettes: marks the palettes in use, not the held one", async function (assert) {
      const palettes = [SOLARIZED_LIGHT, DRACULA, CLOVER];

      await render(
        <template>
          <DSelectColorPalette
            @activeIds={{array 3}}
            @palettes={{palettes}}
            @value={{2}}
          />
        </template>
      );
      await new DSelect().open();

      const badge = find(`${row(3)} .d-select__option-description`);
      assert.dom(badge).hasText("Active");
      assert
        .dom(row(3))
        .hasAttribute(
          "aria-describedby",
          new RegExp(badge.id),
          "read as the row's description, not its name"
        );
      assert.dom(row(3)).hasAttribute("data-name", "Solarized Light");
      assert
        .dom(`${row(2)} .d-select__option-description`)
        .doesNotExist("the held palette isn't marked for being held");
    });

    test("color palettes: the closed field shows the held palette's colors and name", async function (assert) {
      const palettes = [SOLARIZED_LIGHT, DRACULA];

      await render(
        <template>
          <DSelectColorPalette @palettes={{palettes}} @value={{2}} />
        </template>
      );

      assert
        .dom(".d-select .d-select-color-palette__preview")
        .hasAttribute("style", /--tertiary--preview: #bd93f9/);
      assert.dSelect().hasName("Dracula");
    });

    test("color palettes: a list mixing light and dark ones is grouped, light first", async function (assert) {
      const palettes = [DRACULA, SOLARIZED_LIGHT, CLOVER_DARK, CLOVER];

      await render(
        <template><DSelectColorPalette @palettes={{palettes}} /></template>
      );
      await new DSelect().open();

      assert.deepEqual(headings(), ["Light", "Dark"]);
      assert
        .dSelect()
        .hasOptions([3, 4, 2, 5], "in the caller's order within each group");
    });

    test("color palettes: a list of one kind has no headings", async function (assert) {
      const palettes = [DRACULA, CLOVER_DARK];

      await render(
        <template><DSelectColorPalette @palettes={{palettes}} /></template>
      );
      await new DSelect().open();

      assert.deepEqual(headings(), []);
      assert.dSelect().hasOptions([2, 5]);
    });

    test("color palettes: a palette that is neither light nor dark leads, without a heading", async function (assert) {
      const themeDefault = { id: -1, name: "Theme default", colors: [] };
      const palettes = [themeDefault, SOLARIZED_LIGHT, DRACULA];

      await render(
        <template><DSelectColorPalette @palettes={{palettes}} /></template>
      );
      await new DSelect().open();

      assert.deepEqual(headings(), ["Light", "Dark"]);
      assert.dSelect().hasOptions([-1, 3, 2]);
    });

    test("color palettes: a search finds palettes by name", async function (assert) {
      const palettes = [DRACULA, SOLARIZED_LIGHT, CLOVER_DARK, CLOVER];

      await render(
        <template><DSelectColorPalette @palettes={{palettes}} /></template>
      );
      const select = new DSelect();
      await select.open();
      await select.search("clo");

      assert.dSelect().hasOptions([4, 5]);
    });

    test("color palettes: emits the picked palette's id, and null for the none option", async function (assert) {
      const palettes = [SOLARIZED_LIGHT, DRACULA];
      const value = tracked(3);
      const changes = [];
      const onChange = (id) => {
        changes.push(id);
        value.value = id;
      };

      await render(
        <template>
          <DSelectColorPalette
            @noneOption={{true}}
            @onChange={{onChange}}
            @palettes={{palettes}}
            @texts={{hash noneLabel="Light (default)"}}
            @value={{value.value}}
          />
        </template>
      );
      const select = new DSelect();
      await select.open();
      await select.select(2);
      await select.open();
      await select.selectByName("Light (default)");

      assert.deepEqual(changes, [2, null]);
    });

    test("color palettes: the field is named for what it picks", async function (assert) {
      const palettes = [SOLARIZED_LIGHT];

      await render(
        <template><DSelectColorPalette @palettes={{palettes}} /></template>
      );

      assert.dom("[role='combobox']").hasAria("label", "Color palette");
    });

    test("color palettes: a held palette leaves the field as tall as an empty one", async function (assert) {
      const palettes = [fullPalette(7, "Solarized Light")];

      await render(
        <template>
          <DSelectColorPalette
            class="--held"
            @palettes={{palettes}}
            @value={{7}}
          />
          <DSelectColorPalette class="--empty" @palettes={{palettes}} />
        </template>
      );

      assert.strictEqual(
        find(".--held[data-trigger]").offsetHeight,
        find(".--empty[data-trigger]").offsetHeight,
        "so the field keeps its height when its search replaces the palette"
      );
    });

    test("color palettes: each row's strip shows its background, text, accent and selected colors", async function (assert) {
      const palettes = [fullPalette(7, "Solarized Light")];

      await render(
        <template><DSelectColorPalette @palettes={{palettes}} /></template>
      );
      await new DSelect().open();

      assert.deepEqual(
        swatchColors(row(7)),
        [
          "rgb(253, 246, 227)",
          "rgb(7, 54, 66)",
          "rgb(38, 139, 210)",
          "rgb(232, 230, 211)",
        ],
        "the same four squares for every palette, whatever else it colors"
      );
      assert
        .dom(`${row(7)} .d-select-color-palette__swatches`)
        .hasAttribute("aria-hidden", "true");
    });

    test("color palettes: a palette missing one of the four colors has no strip", async function (assert) {
      const palettes = [
        fullPalette(7, "Solarized Light"),
        fullPalette(8, "Saved before selected", { selected: null }),
      ];

      await render(
        <template><DSelectColorPalette @palettes={{palettes}} /></template>
      );
      await new DSelect().open();

      assert.strictEqual(swatchColors(row(7)).length, 4);
      assert
        .dom(`${row(8)} .d-select-color-palette__swatches`)
        .doesNotExist("never a shorter strip");
    });

    test("color palettes: the closed field shows the held palette's strip", async function (assert) {
      const palettes = [fullPalette(7, "Solarized Light")];

      await render(
        <template>
          <DSelectColorPalette @palettes={{palettes}} @value={{7}} />
        </template>
      );

      assert.strictEqual(swatchColors(".d-select[data-trigger]").length, 4);
    });

    test("color palettes: a palette without colors has no strip", async function (assert) {
      const palettes = [{ id: -1, name: "Theme default", colors: [] }];

      await render(
        <template><DSelectColorPalette @palettes={{palettes}} /></template>
      );
      await new DSelect().open();

      assert.dom(`${row(-1)} .d-select-color-palette__swatches`).doesNotExist();
    });

    test("color palettes: a narrow field's list is wide enough to show whole names", async function (assert) {
      const longName = palette(
        6,
        "Solarized Light with a much longer name than fits",
        false,
        "268bd2"
      );
      const palettes = [
        { id: -1, name: "Theme default", colors: [] },
        CLOVER,
        longName,
      ];

      await render(
        <template>
          <div style="width: 8em">
            <DSelectColorPalette @palettes={{palettes}} @value={{-1}} />
          </div>
        </template>
      );
      await new DSelect().open();

      const trigger = find(".d-select[data-trigger]").getBoundingClientRect();
      const panel = find(".d-select__content").getBoundingClientRect();
      assert.true(
        panel.width > trigger.width * 2,
        `the list (${panel.width}px) is wider than the field (${trigger.width}px)`
      );

      for (const id of [-1, 6]) {
        const name = find(`${row(id)} .d-select-color-palette__name`);
        assert.true(
          name.scrollWidth <= name.clientWidth,
          `palette ${id}'s name is shown whole`
        );
      }
      const long = find(`${row(6)} .d-select-color-palette__name`);
      const lineHeight = parseFloat(getComputedStyle(long).lineHeight);
      assert.true(
        long.offsetHeight > lineHeight * 1.5,
        "a name longer than the row wraps"
      );
    });
  }
);
