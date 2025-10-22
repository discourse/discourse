import { hash } from "@ember/helper";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";
import ColorPalettePicker from "select-kit/components/color-palette-picker";

const DEFAULT_CONTENT = [
  {
    name: "Horizon",
    id: 14,
    theme_id: -2,
    colors: [
      {
        name: "primary",
        hex: "1a1a1a",
        default_hex: "222",
        is_advanced: false,
      },
      {
        name: "secondary",
        hex: "ffffff",
        default_hex: "fff",
        is_advanced: false,
      },
      {
        name: "tertiary",
        hex: "595bca",
        default_hex: "08c",
        is_advanced: false,
      },
    ],
    is_dark: false,
  },
  {
    name: "Dark",
    id: 1,
    theme_id: null,
    colors: [
      {
        name: "primary",
        hex: "dddddd",
        default_hex: "dddddd",
        is_advanced: false,
      },
      {
        name: "secondary",
        hex: "222222",
        default_hex: "222222",
        is_advanced: false,
      },
      {
        name: "tertiary",
        hex: "099dd7",
        default_hex: "099dd7",
        is_advanced: false,
      },
    ],
    is_dark: true,
  },
];

const DEFAULT_VALUE = 1;

const setDefaultState = (ctx, options = {}) => {
  const properties = Object.assign(
    {
      content: DEFAULT_CONTENT,
      value: DEFAULT_VALUE,
      onChange: (x) => ctx.set("value", x),
    },
    options
  );
  ctx.setProperties(properties);
};

module(
  "Integration | Component | select-kit/color-palette-picker",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.set("subject", selectKit());
    });

    test("with value", async function (assert) {
      setDefaultState(this);

      const self = this;

      await render(
        <template>
          <ColorPalettePicker
            @content={{self.content}}
            @value={{self.value}}
            @onChange={{self.onChange}}
          />
        </template>
      );

      assert.strictEqual(this.subject.header().value(), "1");
      assert.strictEqual(this.subject.header().label(), "Dark");

      await this.subject.expand();

      assert.dom(".--active", this.subject.rowByValue(1).el()).exists();
      assert.dom(".--active", this.subject.rowByValue(14).el()).doesNotExist();
      assert
        .dom(
          ".color-palette-picker-row__preview",
          this.subject.rowByValue(1).el()
        )
        .exists();
      assert
        .dom(".color-palette-picker-row__name", this.subject.rowByValue(1).el())
        .hasText("Dark");

      await this.subject.selectRowByValue(14);
      await this.subject.expand();

      assert.dom(".--active", this.subject.rowByValue(14).el()).exists();
      assert.dom(".--active", this.subject.rowByValue(1).el()).doesNotExist();
      assert.strictEqual(this.subject.header().value(), "14");
      assert.strictEqual(this.subject.header().label(), "Horizon");
    });

    test("with theme default", async function (assert) {
      setDefaultState(this, { value: null });

      const self = this;

      await render(
        <template>
          <ColorPalettePicker
            @content={{self.content}}
            @value={{self.value}}
            @onChange={{self.onChange}}
            @options={{hash
              translatedNone=(i18n "admin.customize.theme.default_light_scheme")
            }}
          />
        </template>
      );

      await this.subject.expand();

      // hides none(default) theme
      assert.strictEqual(this.subject.rowByIndex(0).name(), "Horizon");

      await this.subject.selectRowByValue(1);
      await this.subject.expand();

      // renders none(default) theme
      assert
        .dom(
          ".color-palette-picker-row__preview",
          this.subject.rowByIndex(0).el()
        )
        .hasStyle({
          "--primary-low--preview": "#e9e9e9",
          "--tertiary-low--preview": "#d1f0ff",
        });
      assert
        .dom(".color-palette-picker-row__name", this.subject.rowByIndex(0).el())
        .hasText(i18n("admin.customize.theme.default_light_scheme"));

      await this.subject.selectRowByIndex(0);

      assert.strictEqual(this.subject.header().value(), null);
      assert.strictEqual(
        this.subject.header().label(),
        i18n("admin.customize.theme.default_light_scheme")
      );
    });
  }
);
