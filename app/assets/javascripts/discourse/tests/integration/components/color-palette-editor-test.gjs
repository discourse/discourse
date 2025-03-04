import { click, find, render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ColorPaletteEditor from "admin/components/color-palette-editor";

function editor() {
  return {
    isActiveModeLight() {
      return this.lightModeNavPill().classList.contains("active");
    },

    isActiveModeDark() {
      return this.darkModeNavPill().classList.contains("active");
    },

    lightModeNavPill() {
      return this.navPills().querySelector(".light-tab");
    },

    darkModeNavPill() {
      return this.navPills().querySelector(".dark-tab");
    },

    navPills() {
      return find(".color-palette-editor__nav-pills");
    },

    async switchToLightTab() {
      await click(this.lightModeNavPill());
    },

    async switchToDarkTab() {
      await click(this.darkModeNavPill());
    },

    color(name) {
      return {
        container() {
          return find(
            `.color-palette-editor__colors-item[data-color-name="${name}"]`
          );
        },

        displayedValue() {
          return this.container().querySelector(
            ".color-palette-editor__color-code"
          ).textContent;
        },

        displayName() {
          return this.container()
            .querySelector(".color-palette-editor__color-name")
            .textContent.trim();
        },

        description() {
          return this.container()
            .querySelector(".color-palette-editor__color-description")
            .textContent.trim();
        },

        input() {
          return this.container().querySelector(".color-palette-editor__input");
        },

        async sendInputEvent(value) {
          const input = this.input();
          input.value = value;
          await triggerEvent(input, "input");
        },

        async sendChangeEvent(value) {
          const input = this.input();
          input.value = value;
          await triggerEvent(input, "change");
        },
      };
    },
  };
}

module("Integration | Component | ColorPaletteEditor", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.subject = editor();
  });

  test("switching between light and dark modes", async function (assert) {
    const colors = [
      {
        name: "primary",
        hex: "aaaaaa",
        dark_hex: "1e3c8a",
      },
      {
        name: "header_background",
        hex: "473921",
        dark_hex: "f2cca9",
      },
    ];

    await render(
      <template><ColorPaletteEditor @colors={{colors}} /></template>
    );

    assert.true(
      this.subject.isActiveModeLight(),
      "light mode tab is active by default"
    );
    assert.false(
      this.subject.isActiveModeDark(),
      "dark mode tab is not active by default"
    );

    assert.strictEqual(
      this.subject.color("primary").input().value,
      "#aaaaaa",
      "input for the primary color is showing the light color"
    );
    assert.strictEqual(
      this.subject.color("primary").displayedValue(),
      "aaaaaa",
      "displayed value for the primary color is showing the light color"
    );

    assert.strictEqual(
      this.subject.color("header_background").input().value,
      "#473921",
      "input for the header_background color is showing the light color"
    );
    assert.strictEqual(
      this.subject.color("header_background").displayedValue(),
      "473921",
      "displayed value for the header_background color is showing the light color"
    );

    await this.subject.switchToDarkTab();

    assert.false(
      this.subject.isActiveModeLight(),
      "light mode tab is now inactive"
    );
    assert.true(this.subject.isActiveModeDark(), "dark mode tab is now active");

    assert.strictEqual(
      this.subject.color("primary").input().value,
      "#1e3c8a",
      "input for the primary color is showing the dark color"
    );
    assert.strictEqual(
      this.subject.color("primary").displayedValue(),
      "1e3c8a",
      "displayed value for the primary color is showing the dark color"
    );

    assert.strictEqual(
      this.subject.color("header_background").input().value,
      "#f2cca9",
      "input for the header_background color is showing the dark color"
    );
    assert.strictEqual(
      this.subject.color("header_background").displayedValue(),
      "f2cca9",
      "displayed value for the header_background color is showing the dark color"
    );
  });

  test("replacing underscores in color name with spaces for display", async function (assert) {
    const colors = [
      {
        name: "my_awesome_color",
        hex: "aaaaaa",
        dark_hex: "1e3c8a",
      },
      {
        name: "header_background",
        hex: "473921",
        dark_hex: "f2cca9",
      },
    ];

    await render(
      <template><ColorPaletteEditor @colors={{colors}} /></template>
    );

    assert.strictEqual(
      this.subject.color("my_awesome_color").displayName(),
      "my awesome color"
    );

    assert.strictEqual(
      this.subject.color("header_background").displayName(),
      "header background"
    );
  });

  test("modifying colors", async function (assert) {
    const colors = [
      {
        name: "primary",
        hex: "aaaaaa",
        dark_hex: "1e3c8a",
      },
      {
        name: "header_background",
        hex: "473921",
        dark_hex: "f2cca9",
      },
    ];

    const lightChanges = [];
    const darkChanges = [];

    const onLightColorChange = (name, value) => {
      lightChanges.push([name, value]);
    };
    const onDarkColorChange = (name, value) => {
      darkChanges.push([name, value]);
    };

    await render(
      <template>
        <ColorPaletteEditor
          @colors={{colors}}
          @onLightColorChange={{onLightColorChange}}
          @onDarkColorChange={{onDarkColorChange}}
        />
      </template>
    );

    await this.subject.color("primary").sendInputEvent("#abcdef");

    assert.strictEqual(
      this.subject.color("primary").input().value,
      "#abcdef",
      "the input element for the primary color changes its value for `input` events"
    );
    assert.strictEqual(
      this.subject.color("primary").displayedValue(),
      "abcdef",
      "displayed value for the primary color updates for `input` events"
    );
    assert.strictEqual(
      lightChanges.length,
      0,
      "light color change callbacks aren't triggered for `input` events"
    );
    assert.strictEqual(
      darkChanges.length,
      0,
      "dark color change callbacks aren't triggered for `input` events"
    );

    await this.subject.color("primary").sendChangeEvent("#fedcba");

    assert.strictEqual(
      this.subject.color("primary").input().value,
      "#fedcba",
      "the input element for the primary color changes its value for `change` events"
    );
    assert.strictEqual(
      this.subject.color("primary").displayedValue(),
      "fedcba",
      "displayed value for the primary color updates for `change` events"
    );
    assert.deepEqual(
      lightChanges,
      [["primary", "fedcba"]],
      "light color change callbacks are triggered for `change` eventswhen the light color changes"
    );

    assert.strictEqual(
      darkChanges.length,
      0,
      "dark color change callbacks aren't triggered for `change` events when the light color changes"
    );

    await this.subject.switchToDarkTab();

    assert.strictEqual(
      this.subject.color("primary").input().value,
      "#1e3c8a",
      "the dark color isn't affected by the change to the light color"
    );
    assert.strictEqual(
      this.subject.color("primary").displayedValue(),
      "1e3c8a",
      "the dark color isn't affected by the change to the light color"
    );

    lightChanges.length = 0;
    darkChanges.length = 0;

    await this.subject.color("header_background").sendInputEvent("#776655");

    assert.strictEqual(
      this.subject.color("header_background").input().value,
      "#776655",
      "the input element for the header_background color changes its value for `input` events"
    );
    assert.strictEqual(
      this.subject.color("header_background").displayedValue(),
      "776655",
      "displayed value for the header_background color updates for `input` events"
    );
    assert.strictEqual(
      lightChanges.length,
      0,
      "light color change callbacks aren't triggered for `input` events"
    );
    assert.strictEqual(
      darkChanges.length,
      0,
      "dark color change callbacks aren't triggered for `input` events"
    );

    await this.subject.color("header_background").sendChangeEvent("#99aaff");

    assert.strictEqual(
      this.subject.color("header_background").input().value,
      "#99aaff",
      "the input element for the header_background color changes its value for `change` events"
    );
    assert.strictEqual(
      this.subject.color("header_background").displayedValue(),
      "99aaff",
      "displayed value for the header_background color updates for `change` events"
    );
    assert.deepEqual(
      darkChanges,
      [["header_background", "99aaff"]],
      "dark color change callbacks are triggered for `change` eventswhen the dark color changes"
    );

    assert.strictEqual(
      lightChanges.length,
      0,
      "light color change callbacks aren't triggered for `change` events when the dark color changes"
    );

    await this.subject.switchToLightTab();

    assert.strictEqual(
      this.subject.color("primary").input().value,
      "#fedcba",
      "the light color for the primary color is remembered after switching tabs"
    );
    assert.strictEqual(
      this.subject.color("primary").displayedValue(),
      "fedcba",
      "the light color for the primary color is remembered after switching tabs"
    );

    assert.strictEqual(
      this.subject.color("header_background").input().value,
      "#473921",
      "the light color for the header_background color remains unchanged"
    );
    assert.strictEqual(
      this.subject.color("header_background").displayedValue(),
      "473921",
      "the light color for the header_background color remains unchanged"
    );

    await this.subject.switchToDarkTab();

    assert.strictEqual(
      this.subject.color("primary").input().value,
      "#1e3c8a",
      "the dark color for the primary color remains unchanged"
    );
    assert.strictEqual(
      this.subject.color("primary").displayedValue(),
      "1e3c8a",
      "the dark color for the primary color remains unchanged"
    );

    assert.strictEqual(
      this.subject.color("header_background").input().value,
      "#99aaff",
      "the dark color for the header_background color is remembered after switching tabs"
    );
    assert.strictEqual(
      this.subject.color("header_background").displayedValue(),
      "99aaff",
      "the dark color for the header_background color is remembered after switching tabs"
    );
  });
});
