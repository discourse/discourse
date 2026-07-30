import { find, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import ColorsSection from "discourse/components/design-wizard/colors-section";
import HomepageSection from "discourse/components/design-wizard/homepage-section";
import ThemeSection from "discourse/components/design-wizard/theme-section";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

const SCREENSHOT = "data:image/gif;base64,R0lGODlhAQABAAD/ACwAAAAAAQABAAACADs=";

module(
  "Integration | Component | DesignWizard | ThemeSection",
  function (hooks) {
    setupRenderingTest(hooks);

    test("theme choices are native radios and the screenshot toggle is focusable", async function (assert) {
      this.setProperties({
        themes: [
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
        ],
        selectedThemeId: -1,
        selectTheme() {},
      });

      await render(
        <template>
          <ThemeSection
            @themes={{this.themes}}
            @selectedThemeId={{this.selectedThemeId}}
            @onSelect={{this.selectTheme}}
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

      const screenshotToggle = find(".design-wizard__theme-screenshot-toggle");
      screenshotToggle.focus();

      assert.strictEqual(
        document.activeElement,
        screenshotToggle,
        "the screenshot toggle can receive keyboard focus"
      );
    });
  }
);

module(
  "Integration | Component | DesignWizard | ColorsSection",
  function (hooks) {
    setupRenderingTest(hooks);

    test("color controls expose their selected state and switch labels", async function (assert) {
      this.setProperties({
        pairs: [
          {
            key: "default",
            name: "Default",
            dark_only: false,
            light: {
              colors: {
                secondary: "ffffff",
                tertiary: "0088cc",
              },
            },
          },
          {
            key: "alternate",
            name: "Alternate",
            dark_only: false,
            light: {
              colors: {
                secondary: "eeeeee",
                tertiary: "ff0000",
              },
            },
          },
        ],
        selectMode() {},
        selectPair() {},
        toggleUserSelectable() {},
      });

      await render(
        <template>
          <ColorsSection
            @pairs={{this.pairs}}
            @selectedPairKey="default"
            @selectedPairName="Default"
            @colorMode="light"
            @darkOnly={{false}}
            @userSelectable={{false}}
            @onSelectMode={{this.selectMode}}
            @onSelectPair={{this.selectPair}}
            @onToggleUserSelectable={{this.toggleUserSelectable}}
          />
        </template>
      );

      assert
        .dom(".design-wizard__color-mode.--active")
        .hasAria("pressed", "true", "exposes the selected color mode");
      assert
        .dom(".design-wizard__swatch[data-pair-key='default']")
        .hasAria("pressed", "true", "exposes the selected palette");
      assert
        .dom(".design-wizard__swatch[data-pair-key='alternate']")
        .hasAria("pressed", "false", "exposes the unselected palette");
      assert
        .dom(".design-wizard__user-selectable [role='switch']")
        .hasAria("checked", "false", "exposes the switch state")
        .hasAria(
          "labelledby",
          "design-wizard-user-selectable-title",
          "associates the switch title"
        )
        .hasAria(
          "describedby",
          "design-wizard-user-selectable-description",
          "associates the switch description"
        );
    });
  }
);

module(
  "Integration | Component | DesignWizard | HomepageSection",
  function (hooks) {
    setupRenderingTest(hooks);

    test("homepage controls expose their selected state", async function (assert) {
      this.setProperties({
        themeId: -1,
        homepage: "latest",
        categoryPageStyle: "categories_boxes",
        selectHomepage() {},
        selectCategoryPageStyle() {},
      });

      await render(
        <template>
          <HomepageSection
            @themeId={{this.themeId}}
            @homepage={{this.homepage}}
            @categoryPageStyle={{this.categoryPageStyle}}
            @onSelectHomepage={{this.selectHomepage}}
            @onSelectCategoryPageStyle={{this.selectCategoryPageStyle}}
          />
        </template>
      );

      assert
        .dom(".design-wizard__homepage-card[data-homepage='topics']")
        .hasAria("pressed", "true", "exposes the selected homepage type");
      assert
        .dom(".design-wizard__topic-page-option[data-topic-page='latest']")
        .hasAria("pressed", "true", "exposes the selected topic page");
      assert
        .dom(".design-wizard__topic-page-option[data-topic-page='new']")
        .hasAria("pressed", "false", "exposes an unselected topic page");

      this.set("homepage", "categories");

      assert
        .dom(".design-wizard__homepage-card[data-homepage='categories']")
        .hasAria("pressed", "true", "exposes the categories homepage");
      assert
        .dom(".design-wizard__style-block[data-style='categories_boxes']")
        .hasAria("pressed", "true", "exposes the selected category style");
    });
  }
);
