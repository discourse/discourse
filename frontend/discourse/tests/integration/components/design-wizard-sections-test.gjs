import { tracked } from "@glimmer/tracking";
import { click, find, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import ColorsSection from "discourse/components/design-wizard/colors-section";
import HomepageSection from "discourse/components/design-wizard/homepage-section";
import SearchSection from "discourse/components/design-wizard/search-section";
import ThemeSection from "discourse/components/design-wizard/theme-section";
import WelcomeBannerSection from "discourse/components/design-wizard/welcome-banner-section";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

const SCREENSHOT = "data:image/gif;base64,R0lGODlhAQABAAD/ACwAAAAAAQABAAACADs=";

const noop = () => {};
const noSidebarColors = () => undefined;

const PAIRS = [
  {
    key: "default",
    name: "Default",
    dark_only: false,
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
    dark_only: false,
    light: { colors: { secondary: "eeeeee", tertiary: "ff0000" } },
    dark: { colors: { secondary: "222222", tertiary: "ff4444" } },
  },
];

const DARK_ONLY_PAIR = {
  key: "dracula",
  name: "Dracula",
  dark_only: true,
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
            @darkOff={{false}}
            @darkPairs={{PAIRS}}
            @lightOff={{false}}
            @lightPairs={{PAIRS}}
            @onSelectPalette={{select}}
            @selectedDarkKey="alternate"
            @selectedLightKey="default"
            @sidebarColorsFor={{noSidebarColors}}
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
        .dom(`${LIGHT} .design-wizard__palette-row-status`)
        .hasText("Site default");

      const preview = find(
        `${LIGHT} [data-pair-key='default'] .design-wizard__palette-preview`
      );
      assert.strictEqual(
        preview.style.getPropertyValue("--palette-quaternary"),
        "#e45735",
        "previews the palette's own colors"
      );
      assert.strictEqual(
        find(
          `${DARK} [data-pair-key='default'] .design-wizard__palette-preview`
        ).style.getPropertyValue("--palette-secondary"),
        "#111111",
        "the dark row previews the dark palette"
      );

      await click(`${DARK} [data-pair-key='default']`);
      assert.deepEqual(
        selections,
        [["dark", "default"]],
        "reports the row and palette picked"
      );
    });

    test("the sidebar strip uses the theme's colors once they resolve", async function (assert) {
      const sidebarColorsFor = (palette, mode) =>
        mode === "light" && palette === PAIRS[0].light
          ? {
              background: "rgb(1, 2, 3)",
              active: "rgb(4, 5, 6)",
              link: "rgb(7, 8, 9)",
              border: null,
            }
          : undefined;

      await render(
        <template>
          <ColorsSection
            @darkOff={{false}}
            @darkPairs={{PAIRS}}
            @lightOff={{false}}
            @lightPairs={{PAIRS}}
            @onSelectPalette={{noop}}
            @selectedDarkKey="default"
            @selectedLightKey="default"
            @sidebarColorsFor={{sidebarColorsFor}}
          />
        </template>
      );

      const style = (selector) =>
        find(`${selector} .design-wizard__palette-preview`).style;

      const resolved = style(
        ".design-wizard__palette-row[data-mode='light'] [data-pair-key='default']"
      );
      assert.strictEqual(
        resolved.getPropertyValue("--palette-sidebar-background"),
        "rgb(1, 2, 3)",
        "uses the theme's sidebar background"
      );
      assert.strictEqual(
        resolved.getPropertyValue("--palette-sidebar-active"),
        "rgb(4, 5, 6)"
      );
      assert.strictEqual(
        resolved.getPropertyValue("--palette-sidebar-link"),
        "rgb(7, 8, 9)"
      );
      assert.strictEqual(
        resolved.getPropertyValue("--palette-sidebar-border"),
        "transparent",
        "draws no divider when the theme has none"
      );

      const pending = style(
        ".design-wizard__palette-row[data-mode='dark'] [data-pair-key='default']"
      );
      assert.strictEqual(
        pending.getPropertyValue("--palette-sidebar-background"),
        "#111111",
        "blends the strip into the content until the colors resolve"
      );
    });

    test("turning a mode off uses the other mode's palette for both", async function (assert) {
      const darkPairs = [...PAIRS, DARK_ONLY_PAIR];
      const selections = [];
      const select = (mode, key) => selections.push([mode, key]);

      await render(
        <template>
          <ColorsSection
            @darkOff={{false}}
            @darkPairs={{darkPairs}}
            @lightOff={{true}}
            @lightPairs={{PAIRS}}
            @onSelectPalette={{select}}
            @selectedDarkKey="dracula"
            @sidebarColorsFor={{noSidebarColors}}
            @singlePaletteName="Dracula"
          />
        </template>
      );

      const LIGHT = ".design-wizard__palette-row[data-mode='light']";
      const DARK = ".design-wizard__palette-row[data-mode='dark']";

      assert
        .dom(`${LIGHT} [data-pair-key='none']`)
        .hasAria("pressed", "true", "selects none for light mode")
        .includesText("None");
      assert
        .dom(`${LIGHT} [data-pair-key='default']`)
        .isEnabled("light palettes can still be picked")
        .hasAria("pressed", "false");
      assert.dom(`${LIGHT} .design-wizard__palette-row-status`).hasText("Off");
      assert
        .dom(`${DARK} .design-wizard__palette-row-status`)
        .hasText("Used for both modes");
      assert
        .dom(`${DARK} [data-pair-key='none']`)
        .isDisabled("both modes can't be off at once");
      assert
        .dom(`${DARK} [data-pair-key='dracula'] .sr-only`)
        .hasText("Dark mode only", "labels the moon icon");
      assert
        .dom(".design-wizard__palette-note-region[aria-live='polite']")
        .includesText(
          "Dracula is used in both light and dark mode",
          "announces the note"
        );

      await click(`${LIGHT} [data-pair-key='default']`);
      assert.deepEqual(
        selections,
        [["light", "default"]],
        "switches light mode back on"
      );
    });

    test("each row offers none while the other mode has a palette", async function (assert) {
      await render(
        <template>
          <ColorsSection
            @darkOff={{false}}
            @darkPairs={{PAIRS}}
            @lightOff={{false}}
            @lightPairs={{PAIRS}}
            @onSelectPalette={{noop}}
            @selectedDarkKey="default"
            @selectedLightKey="default"
            @sidebarColorsFor={{noSidebarColors}}
          />
        </template>
      );

      assert
        .dom(
          ".design-wizard__palette-card[data-pair-key='none']:not(:disabled)"
        )
        .exists({ count: 2 });
      assert
        .dom(".design-wizard__palette-card[data-pair-key='none']")
        .hasAria("pressed", "false");
      assert
        .dom(".design-wizard__palette-note")
        .doesNotExist("shows no note while both modes have a palette");
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
        .dom(".design-wizard__option-row[data-topic-page='latest']")
        .hasAria("pressed", "true", "exposes the selected topic page");
      assert
        .dom(".design-wizard__option-row[data-topic-page='new']")
        .hasAria("pressed", "false", "exposes an unselected topic page");

      homepage.value = "categories";
      await settled();

      assert
        .dom(".design-wizard__homepage-card[data-homepage='categories']")
        .hasAria("pressed", "true", "exposes the categories homepage");
      assert
        .dom(".design-wizard__style-block[data-style='categories_boxes']")
        .hasAria("pressed", "true", "exposes the selected category style");
      assert
        .dom(".design-wizard__option-row")
        .doesNotExist("hides the topic page types for a categories homepage");
    });
  }
);

module(
  "Integration | Component | DesignWizard | WelcomeBannerSection",
  function (hooks) {
    setupRenderingTest(hooks);

    test("the location choices only appear once the banner is enabled", async function (assert) {
      const enabled = tracked(false);
      const toggle = () => (enabled.value = !enabled.value);

      await render(
        <template>
          <WelcomeBannerSection
            @enabled={{enabled.value}}
            @location="above_topic_content"
            @onSelectLocation={{noop}}
            @onToggle={{toggle}}
          />
        </template>
      );

      const SWITCH = ".design-wizard__switch-row [role='switch']";
      assert.dom(SWITCH).hasAria("checked", "false", "starts off");
      assert
        .dom(".design-wizard__option-row[data-welcome-banner-location]")
        .doesNotExist("hides the locations while the banner is off");

      await click(SWITCH);

      assert.true(enabled.value, "clicking the switch notifies the caller");
      assert
        .dom(
          ".design-wizard__option-row[data-welcome-banner-location='above_topic_content']"
        )
        .hasAria("pressed", "true", "exposes the selected location");
      assert
        .dom(
          ".design-wizard__option-row[data-welcome-banner-location='below_site_header']"
        )
        .hasAria("pressed", "false", "exposes an unselected location");
    });
  }
);

module(
  "Integration | Component | DesignWizard | SearchSection",
  function (hooks) {
    setupRenderingTest(hooks);

    test("search controls expose their selected state", async function (assert) {
      const selected = [];
      const select = (experience) => selected.push(experience);

      await render(
        <template>
          <SearchSection @onSelect={{select}} @searchExperience="search_icon" />
        </template>
      );

      assert
        .dom(".design-wizard__option-row[data-search-experience='search_icon']")
        .hasAria("pressed", "true", "exposes the selected experience");
      assert
        .dom(
          ".design-wizard__option-row[data-search-experience='search_field']"
        )
        .hasAria("pressed", "false", "exposes an unselected experience");

      await click(
        ".design-wizard__option-row[data-search-experience='search_field']"
      );

      assert.deepEqual(
        selected,
        ["search_field"],
        "notifies the caller of the chosen experience"
      );
    });
  }
);
