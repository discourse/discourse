import { tracked } from "@glimmer/tracking";
import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import ColorsSection from "discourse/components/design-wizard/colors-section";
import HomepageSection from "discourse/components/design-wizard/homepage-section";
import ThemeSection from "discourse/components/design-wizard/theme-section";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

const SCREENSHOT = "data:image/gif;base64,R0lGODlhAQABAAD/ACwAAAAAAQABAAACADs=";

const noop = () => {};

const PAIRS = [
  {
    key: "default",
    name: "Default",
    dark_only: false,
    light: { colors: { secondary: "ffffff", tertiary: "0088cc" } },
  },
  {
    key: "alternate",
    name: "Alternate",
    dark_only: false,
    light: { colors: { secondary: "eeeeee", tertiary: "ff0000" } },
  },
];

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
            @themes={{themes}}
            @selectedThemeId={{-1}}
            @onSelect={{noop}}
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
    });
  }
);

module(
  "Integration | Component | DesignWizard | ColorsSection",
  function (hooks) {
    setupRenderingTest(hooks);

    test("color controls expose their selected state and switch labels", async function (assert) {
      await render(
        <template>
          <ColorsSection
            @pairs={{PAIRS}}
            @selectedPairKey="default"
            @selectedPairName="Default"
            @colorMode="light"
            @darkOnly={{false}}
            @userSelectable={{false}}
            @onSelectMode={{noop}}
            @onSelectPair={{noop}}
            @onToggleUserSelectable={{noop}}
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

    test("the user selectable switch reflects and toggles its state", async function (assert) {
      const state = new (class {
        @tracked userSelectable = false;
      })();
      const toggle = () => (state.userSelectable = !state.userSelectable);

      await render(
        <template>
          <ColorsSection
            @pairs={{PAIRS}}
            @selectedPairKey="default"
            @selectedPairName="Default"
            @colorMode="light"
            @darkOnly={{false}}
            @userSelectable={{state.userSelectable}}
            @onSelectMode={{noop}}
            @onSelectPair={{noop}}
            @onToggleUserSelectable={{toggle}}
          />
        </template>
      );

      const SWITCH = ".design-wizard__user-selectable [role='switch']";
      assert.dom(SWITCH).hasAria("checked", "false", "starts off");

      await click(SWITCH);
      assert.true(
        state.userSelectable,
        "clicking the switch notifies the caller"
      );
      assert.dom(SWITCH).hasAria("checked", "true", "renders the new state");

      await click(SWITCH);
      assert.false(state.userSelectable, "clicking again toggles back off");
      assert
        .dom(SWITCH)
        .hasAria("checked", "false", "renders the reverted state");
    });
  }
);

module(
  "Integration | Component | DesignWizard | HomepageSection",
  function (hooks) {
    setupRenderingTest(hooks);

    test("homepage controls expose their selected state", async function (assert) {
      const state = new (class {
        @tracked homepage = "latest";
      })();

      await render(
        <template>
          <HomepageSection
            @themeId={{-1}}
            @homepage={{state.homepage}}
            @categoryPageStyle="categories_boxes"
            @onSelectHomepage={{noop}}
            @onSelectCategoryPageStyle={{noop}}
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

      state.homepage = "categories";
      await settled();

      assert
        .dom(".design-wizard__homepage-card[data-homepage='categories']")
        .hasAria("pressed", "true", "exposes the categories homepage");
      assert
        .dom(".design-wizard__style-block[data-style='categories_boxes']")
        .hasAria("pressed", "true", "exposes the selected category style");
      assert
        .dom(".design-wizard__topic-page-option")
        .doesNotExist("hides the topic page types for a categories homepage");
    });
  }
);
