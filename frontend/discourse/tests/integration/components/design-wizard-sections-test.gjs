import { tracked } from "@glimmer/tracking";
import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import ColorsSection from "discourse/components/design-wizard/colors-section";
import HomepageSection from "discourse/components/design-wizard/homepage-section";
import ThemeSection from "discourse/components/design-wizard/theme-section";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

const SCREENSHOT = "data:image/gif;base64,R0lGODlhAQABAAD/ACwAAAAAAQABAAACADs=";

const noop = () => {};
const NO_PAIRS = [];

const PAIRS = [
  {
    key: "default",
    name: "Default",
    light: {
      colors: {
        secondary: "ffffff",
        primary: "222222",
        tertiary: "0088cc",
        quaternary: "e45735",
        love: "fa6c8d",
        highlight: "ffff4d",
      },
    },
    dark: { colors: { secondary: "111111", tertiary: "00aaff" } },
  },
  {
    key: "alternate",
    name: "Alternate",
    light: { colors: { secondary: "eeeeee", tertiary: "ff0000" } },
    dark: { colors: { secondary: "222222", tertiary: "ff4444" } },
  },
];

const DRACULA_PAIR = {
  key: "dracula",
  name: "Dracula",
  light: null,
  dark: { colors: { secondary: "2d303e", tertiary: "bd93f9" } },
};

module(
  "Integration | Component | DesignWizard | ThemeSection",
  function (hooks) {
    setupRenderingTest(hooks);

    test("theme choices are native radios", async function (assert) {
      const themes = [
        {
          id: -1,
          name: "Foundation",
          screenshot_light_url: SCREENSHOT,
          screenshot_dark_url: SCREENSHOT,
        },
        {
          id: -2,
          name: "Horizon",
          screenshot_light_url: null,
          screenshot_dark_url: null,
        },
      ];

      await render(
        <template>
          <ThemeSection
            @onSelect={{noop}}
            @selectedThemeId={{-1}}
            @themes={{themes}}
          />
        </template>
      );

      assert
        .dom(".design-wizard__theme-cards legend")
        .hasText("Choose a theme", "labels the group of themes");
      assert
        .dom(
          ".design-wizard__theme-card input[type='radio'][name='design-wizard-theme']"
        )
        .exists({ count: 2 }, "renders one native radio per theme");
      assert
        .dom(
          ".design-wizard__theme-card[data-theme-id='-1'] input[type='radio']"
        )
        .isChecked("checks the selected theme");
      assert
        .dom(
          ".design-wizard__theme-card[data-theme-id='-2'] input[type='radio']"
        )
        .isNotChecked("leaves the other theme unchecked");
      assert
        .dom(
          ".design-wizard__theme-card[data-theme-id='-2'] .design-wizard__theme-screenshot"
        )
        .doesNotExist(
          "does not render an empty screenshot for a theme without one"
        );
      assert
        .dom(".design-wizard__theme-card[data-theme-id='-2']")
        .hasClass(
          "--without-screenshot",
          "uses a compact card without a screenshot"
        );
    });

    test("applying a theme locks the choices while the preview loads", async function (assert) {
      const themes = [
        { id: -1, name: "Foundation", screenshot_light_url: SCREENSHOT },
        { id: -2, name: "Horizon", screenshot_light_url: SCREENSHOT },
      ];

      await render(
        <template>
          <ThemeSection
            @applying={{true}}
            @onSelect={{noop}}
            @selectedThemeId={{-1}}
            @themes={{themes}}
          />
        </template>
      );

      assert
        .dom(".design-wizard__theme-cards")
        .hasAttribute("aria-busy", "true", "marks the choices as busy");
      assert
        .dom(".design-wizard__theme-card input[type='radio']")
        .isDisabled("stops a second theme being picked mid-preview");
      assert
        .dom(
          ".design-wizard__theme-card[data-theme-id='-1'] .design-wizard__theme-spinner"
        )
        .exists("shows progress on the theme being applied");
    });
  }
);

module(
  "Integration | Component | DesignWizard | ColorsSection",
  function (hooks) {
    setupRenderingTest(hooks);

    test("palette cards expose their selected state and preview colors", async function (assert) {
      const selections = [];
      const select = (mode, key) => selections.push([mode, key]);

      await render(
        <template>
          <ColorsSection
            @darkPairs={{PAIRS}}
            @lightPairs={{PAIRS}}
            @onSelectPalette={{select}}
            @paletteMode="both"
            @selectedDarkKey="alternate"
            @selectedLightKey="default"
            @showsDarkPalettes={{true}}
            @showsLightPalettes={{true}}
          />
        </template>
      );

      const LIGHT = ".design-wizard__palette-row[data-mode='light']";
      const DARK = ".design-wizard__palette-row[data-mode='dark']";

      assert
        .dom(`${LIGHT} [data-pair-key='default']`)
        .hasAria("pressed", "true", "exposes the selected light palette");
      assert
        .dom(`${LIGHT} [data-pair-key='alternate']`)
        .hasAria("pressed", "false", "exposes an unselected light palette");
      assert
        .dom(`${DARK} [data-pair-key='alternate']`)
        .hasAria("pressed", "true", "selects each row independently");
      assert
        .dom(`${LIGHT} .design-wizard__palette-row-selected`)
        .hasText("Default", "names the selected light palette");
      assert
        .dom(`${DARK} .design-wizard__palette-row-selected`)
        .hasText("Alternate", "names the selected dark palette");

      assert
        .dom(
          `${LIGHT} [data-pair-key='default'] .design-wizard__palette-preview`
        )
        .hasAttribute("style", /#0088cc/, "previews the palette's own colors");
      assert
        .dom(
          `${DARK} [data-pair-key='default'] .design-wizard__palette-preview`
        )
        .hasAttribute(
          "style",
          /#00aaff/,
          "the dark row previews the dark palette"
        );

      await click(`${DARK} [data-pair-key='default']`);
      assert.deepEqual(
        selections,
        [["dark", "default"]],
        "reports the row and palette picked"
      );
    });

    test("the color mode control picks which rows are shown", async function (assert) {
      const darkPairs = [...PAIRS, DRACULA_PAIR];
      const modes = [];
      const selectMode = (mode) => modes.push(mode);

      await render(
        <template>
          <ColorsSection
            @darkPairs={{darkPairs}}
            @lightPairs={{PAIRS}}
            @onSelectPalette={{noop}}
            @onSelectPaletteMode={{selectMode}}
            @paletteMode="dark"
            @selectedDarkKey="dracula"
            @showsDarkPalettes={{true}}
            @showsLightPalettes={{false}}
          />
        </template>
      );

      assert
        .dom(".design-wizard__palette-modes legend")
        .hasText("Color modes", "labels the control");
      assert
        .dom(".design-wizard__palette-modes input[value='dark']")
        .isChecked("reflects the selected mode");
      assert
        .dom(".design-wizard__palette-row[data-mode='light']")
        .doesNotExist("hides the light row on a dark-only site");
      assert
        .dom(
          ".design-wizard__palette-row[data-mode='dark'] [data-pair-key='dracula']"
        )
        .hasAria("pressed", "true");

      await click(".design-wizard__palette-modes input[value='both']");
      assert.deepEqual(modes, ["both"], "reports the mode picked");
    });

    test("modes without palettes can't be picked", async function (assert) {
      await render(
        <template>
          <ColorsSection
            @darkPairs={{NO_PAIRS}}
            @lightPairs={{PAIRS}}
            @onSelectPalette={{noop}}
            @onSelectPaletteMode={{noop}}
            @paletteMode="light"
            @selectedLightKey="default"
            @showsDarkPalettes={{false}}
            @showsLightPalettes={{true}}
          />
        </template>
      );

      assert
        .dom(".design-wizard__palette-modes input[value='light']")
        .isEnabled();
      assert
        .dom(".design-wizard__palette-modes input[value='both']")
        .isDisabled();
      assert
        .dom(".design-wizard__palette-modes input[value='dark']")
        .isDisabled();
    });
  }
);

module(
  "Integration | Component | DesignWizard | HomepageSection",
  function (hooks) {
    setupRenderingTest(hooks);

    test("homepage controls expose their selected state", async function (assert) {
      const homepage = tracked("latest");

      await render(
        <template>
          <HomepageSection
            @categoryPageStyle="categories_boxes"
            @homepage={{homepage.value}}
            @onSelectCategoryPageStyle={{noop}}
            @onSelectHomepage={{noop}}
            @themeId={{-1}}
          />
        </template>
      );

      assert
        .dom(".design-wizard__homepage-card[data-homepage='topics']")
        .hasAria("pressed", "true", "exposes the selected homepage type");
      assert
        .dom(".design-wizard__detail-group")
        .doesNotExist("offers no further choices for a topics homepage");

      homepage.value = "categories";
      await settled();

      assert
        .dom(".design-wizard__homepage-card[data-homepage='categories']")
        .hasAria("pressed", "true", "exposes the categories homepage");
      assert
        .dom(".design-wizard__style-block[data-style='categories_boxes']")
        .hasAria("pressed", "true", "exposes the selected category style");
    });
  }
);
