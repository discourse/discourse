import { find, render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ColorPaletteEditor from "admin/components/color-palette-editor";
import ColorSchemeColor from "admin/models/color-scheme-color";

function editor() {
  return {
    color(name) {
      return {
        container() {
          return find(
            `.color-palette-editor__colors-item[data-color-name="${name}"]`
          );
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

        colorInput() {
          return this.container().querySelector(".color-palette-editor__input");
        },

        textInput() {
          return this.container().querySelector(
            ".color-palette-editor__text-input"
          );
        },

        async sendColorInputEvent(value) {
          const input = this.colorInput();
          input.value = value;
          await triggerEvent(input, "input");
        },

        async sendColorChangeEvent(value) {
          const input = this.colorInput();
          input.value = value;
          await triggerEvent(input, "change");
        },

        async sendTextChangeEvent(value) {
          const input = this.textInput();
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

  test("uses the i18n string for the color name", async function (assert) {
    const colors = [
      {
        name: "header_background",
        hex: "473921",
      },
    ].map((data) => ColorSchemeColor.create(data));

    await render(
      <template><ColorPaletteEditor @colors={{colors}} /></template>
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
      },
      {
        name: "header_background",
        hex: "473921",
      },
    ].map((data) => ColorSchemeColor.create(data));

    const changes = [];

    const onColorChange = (color, value) => {
      changes.push([color.name, value]);
      color.hex = value;
    };

    await render(
      <template>
        <ColorPaletteEditor
          @colors={{colors}}
          @onColorChange={{onColorChange}}
        />
      </template>
    );

    await this.subject.color("primary").sendColorInputEvent("#abcdef");

    assert.strictEqual(
      this.subject.color("primary").colorInput().value,
      "#abcdef",
      "the input element for the primary color changes its value for `input` events"
    );
    assert.strictEqual(
      this.subject.color("primary").textInput().value,
      "abcdef",
      "text input value for the primary color updates for `input` events"
    );
    assert.deepEqual(
      changes,
      [["primary", "abcdef"]],
      "color change callback is triggered for `input` events"
    );

    await this.subject.color("primary").sendColorChangeEvent("#fedcba");

    assert.strictEqual(
      this.subject.color("primary").colorInput().value,
      "#fedcba",
      "the input element for the primary color changes its value for `change` events"
    );
    assert.strictEqual(
      this.subject.color("primary").textInput().value,
      "fedcba",
      "text input value for the primary color updates for `change` events"
    );
    assert.deepEqual(
      changes,
      [
        ["primary", "abcdef"],
        ["primary", "fedcba"],
      ],
      "color change callback is triggered for `change` events when the color changes"
    );
  });

  test("changing the text input field updates the color picker", async function (assert) {
    const colors = [
      {
        name: "primary",
        hex: "aaaaaa",
      },
    ].map((data) => ColorSchemeColor.create(data));

    const changes = [];

    const onColorChange = (color, value) => {
      changes.push([color.name, value]);
      color.hex = value;
    };

    await render(
      <template>
        <ColorPaletteEditor
          @colors={{colors}}
          @onColorChange={{onColorChange}}
        />
      </template>
    );

    await this.subject.color("primary").sendTextChangeEvent("9999cc");

    assert.strictEqual(
      this.subject.color("primary").colorInput().value,
      "#9999cc",
      "the color input reflects the text input"
    );
    assert.deepEqual(
      changes,
      [["primary", "9999cc"]],
      "color change callback is triggered for `change` events when the color changes"
    );
  });

  test("converting 3 digits hex values to 6 digits", async function (assert) {
    const colors = [
      {
        name: "primary",
        hex: "a8c",
      },
    ].map((data) => ColorSchemeColor.create(data));

    await render(
      <template><ColorPaletteEditor @colors={{colors}} /></template>
    );

    assert.strictEqual(
      this.subject.color("primary").colorInput().value,
      "#aa88cc",
      "the input field has the equivalent 6 digits value"
    );
    assert.strictEqual(
      this.subject.color("primary").textInput().value,
      "aa88cc",
      "the text input value shows the 6 digits format"
    );
  });

  test("validates hex color input", async function (assert) {
    const colors = [
      {
        name: "primary",
        hex: "aaaaaa",
      },
    ].map((data) => ColorSchemeColor.create(data));

    const changes = [];

    const onColorChange = (color, value) => {
      changes.push([color.name, value]);
      color.hex = value;
    };

    await render(
      <template>
        <ColorPaletteEditor
          @colors={{colors}}
          @onColorChange={{onColorChange}}
        />
      </template>
    );

    await this.subject.color("primary").sendTextChangeEvent("333333");
    assert.strictEqual(
      this.subject.color("primary").colorInput().value,
      "#333333",
      "valid 6-digit hex color is accepted"
    );
    assert.deepEqual(
      changes,
      [["primary", "333333"]],
      "color change callback is called with the expanded value"
    );
    changes.length = 0;

    await this.subject.color("primary").sendTextChangeEvent("abc");
    assert.strictEqual(
      this.subject.color("primary").colorInput().value,
      "#aabbcc",
      "valid 3-digit hex color is accepted and expanded"
    );
    assert.deepEqual(
      changes,
      [["primary", "aabbcc"]],
      "color change callback is called with the expanded value"
    );
    changes.length = 0;

    await this.subject.color("primary").sendTextChangeEvent("gggggg");
    assert.strictEqual(
      this.subject.color("primary").colorInput().value,
      "#aabbcc",
      "invalid hex color is rejected"
    );
    assert.strictEqual(
      changes.length,
      0,
      "color change callback is not called"
    );
  });

  test("keypress events handle hex validation", async function (assert) {
    const colors = [
      {
        name: "primary",
        hex: "aaaaaa",
      },
    ].map((data) => ColorSchemeColor.create(data));

    await render(
      <template><ColorPaletteEditor @colors={{colors}} /></template>
    );

    const textInput = this.subject.color("primary").textInput();
    const event = new KeyboardEvent("keypress", {
      key: "g",
      bubbles: true,
      cancelable: true,
    });

    textInput.dispatchEvent(event);
    assert.true(
      event.defaultPrevented,
      "non-hex character keypress is prevented"
    );

    const validEvent = new KeyboardEvent("keypress", {
      key: "a",
      bubbles: true,
      cancelable: true,
    });
    textInput.dispatchEvent(validEvent);
    assert.false(
      validEvent.defaultPrevented,
      "hex character keypress is allowed"
    );
  });

  test("Enter key navigates to next color field", async function (assert) {
    const colors = [
      {
        name: "primary",
        hex: "aaaaaa",
      },
      {
        name: "secondary",
        hex: "bbbbbb",
      },
      {
        name: "tertiary",
        hex: "cccccc",
      },
    ].map((data) => ColorSchemeColor.create(data));

    await render(
      <template><ColorPaletteEditor @colors={{colors}} /></template>
    );

    this.subject.color("primary").textInput().focus();
    assert.strictEqual(
      document.activeElement,
      this.subject.color("primary").textInput(),
      "primary color input is focused"
    );

    const enterEvent = new KeyboardEvent("keypress", {
      keyCode: 13,
      bubbles: true,
      cancelable: true,
    });
    document.activeElement.dispatchEvent(enterEvent);

    assert.strictEqual(
      document.activeElement,
      this.subject.color("secondary").textInput(),
      "secondary color input is focused after Enter key"
    );
  });

  test("paste event validates hex color input", async function (assert) {
    const toastService = this.owner.lookup("service:toasts");

    const colors = [
      {
        name: "primary",
        hex: "aaaaaa",
      },
    ].map((data) => ColorSchemeColor.create(data));

    const onColorChange = (color, value) => {
      color.hex = value;
    };

    await render(
      <template>
        <ColorPaletteEditor
          @colors={{colors}}
          @onColorChange={{onColorChange}}
        />
      </template>
    );

    const textInput = this.subject.color("primary").textInput();

    const validPasteEvent = new ClipboardEvent("paste", {
      clipboardData: new DataTransfer(),
      bubbles: true,
      cancelable: true,
    });
    validPasteEvent.clipboardData.setData("text", "123abc");
    textInput.dispatchEvent(validPasteEvent);
    assert.strictEqual(
      toastService.activeToasts.length,
      0,
      "no error toast is shown for valid hex color paste"
    );

    const invalidPasteEvent = new ClipboardEvent("paste", {
      clipboardData: new DataTransfer(),
      bubbles: true,
      cancelable: true,
    });
    invalidPasteEvent.clipboardData.setData("text", "xyz123");
    textInput.dispatchEvent(invalidPasteEvent);
    assert.true(
      invalidPasteEvent.defaultPrevented,
      "invalid hex color paste is prevented"
    );
    assert.strictEqual(
      toastService.activeToasts.length,
      1,
      "a toast is shown for invalid hex color paste"
    );
    const toast = toastService.activeToasts[0];
    assert.strictEqual(
      toast.options.data.theme,
      "error",
      "toast is an error type"
    );
  });

  test("shows error for invalid color length on Enter", async function (assert) {
    const toastService = this.owner.lookup("service:toasts");

    const colors = [
      {
        name: "primary",
        hex: "aaaaaa",
      },
    ].map((data) => ColorSchemeColor.create(data));

    await render(
      <template><ColorPaletteEditor @colors={{colors}} /></template>
    );

    const textInput = this.subject.color("primary").textInput();
    textInput.value = "1234";

    const enterEvent = new KeyboardEvent("keypress", {
      keyCode: 13,
      bubbles: true,
      cancelable: true,
    });
    textInput.dispatchEvent(enterEvent);
    assert.strictEqual(
      toastService.activeToasts.length,
      1,
      "a toast is shown for invalid color length"
    );
    const toast = toastService.activeToasts[0];
    assert.strictEqual(
      toast.options.data.theme,
      "error",
      "toast is an error type"
    );
    assert.true(
      enterEvent.defaultPrevented,
      "Enter key default action is prevented"
    );
  });
});
