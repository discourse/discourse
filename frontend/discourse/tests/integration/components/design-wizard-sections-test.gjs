import { tracked } from "@glimmer/tracking";
import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import ColorsSection from "discourse/components/design-wizard/colors-section";
import HomepageSection from "discourse/components/design-wizard/homepage-section";
import SearchSection from "discourse/components/design-wizard/search-section";
import ThemeSection from "discourse/components/design-wizard/theme-section";
import WelcomeBannerSection from "discourse/components/design-wizard/welcome-banner-section";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

const SCREENSHOT = "data:image/gif;base64,R0lGODlhAQABAAD/ACwAAAAAAQABAAACADs=";

const noop = () => {};

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

    test("turning a mode off uses the other mode's palette for both", async function (assert) {
      const darkPairs = [...PAIRS, DRACULA_PAIR];
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
