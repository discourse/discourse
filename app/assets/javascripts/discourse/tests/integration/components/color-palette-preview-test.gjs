import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import ColorPalettePreview from "discourse/components/color-palette-preview";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

const example_scheme = {
  name: "Solarized Light",
  id: 5,
  theme_id: null,
  colors: [
    {
      name: "primary_very_low",
      hex: "F0ECD7",
      default_hex: "F0ECD7",
      is_advanced: true,
    },
    {
      name: "primary_low",
      hex: "D6D8C7",
      default_hex: "D6D8C7",
      is_advanced: true,
    },
    {
      name: "primary_low_mid",
      hex: "A4AFA5",
      default_hex: "A4AFA5",
      is_advanced: true,
    },
    {
      name: "primary_medium",
      hex: "7E918C",
      default_hex: "7E918C",
      is_advanced: true,
    },
    {
      name: "primary_high",
      hex: "4C6869",
      default_hex: "4C6869",
      is_advanced: true,
    },
    {
      name: "primary",
      hex: "002B36",
      default_hex: "002B36",
      is_advanced: false,
    },
    {
      name: "primary-50",
      hex: "F0EBDA",
      default_hex: "F0EBDA",
      is_advanced: true,
    },
    {
      name: "primary-100",
      hex: "DAD8CA",
      default_hex: "DAD8CA",
      is_advanced: true,
    },
    {
      name: "primary-200",
      hex: "B2B9B3",
      default_hex: "B2B9B3",
      is_advanced: true,
    },
    {
      name: "primary-300",
      hex: "839496",
      default_hex: "839496",
      is_advanced: true,
    },
    {
      name: "primary-400",
      hex: "76898C",
      default_hex: "76898C",
      is_advanced: true,
    },
    {
      name: "primary-500",
      hex: "697F83",
      default_hex: "697F83",
      is_advanced: true,
    },
    {
      name: "primary-600",
      hex: "627A7E",
      default_hex: "627A7E",
      is_advanced: true,
    },
    {
      name: "primary-700",
      hex: "556F74",
      default_hex: "556F74",
      is_advanced: true,
    },
    {
      name: "primary-800",
      hex: "415F66",
      default_hex: "415F66",
      is_advanced: true,
    },
    {
      name: "primary-900",
      hex: "21454E",
      default_hex: "21454E",
      is_advanced: true,
    },
    {
      name: "secondary_low",
      hex: "325458",
      default_hex: "325458",
      is_advanced: true,
    },
    {
      name: "secondary_medium",
      hex: "6C8280",
      default_hex: "6C8280",
      is_advanced: true,
    },
    {
      name: "secondary_high",
      hex: "97A59D",
      default_hex: "97A59D",
      is_advanced: true,
    },
    {
      name: "secondary_very_high",
      hex: "E8E6D3",
      default_hex: "E8E6D3",
      is_advanced: true,
    },
    {
      name: "secondary",
      hex: "FCF6E1",
      default_hex: "FCF6E1",
      is_advanced: false,
    },
    {
      name: "tertiary_low",
      hex: "D6E6DE",
      default_hex: "D6E6DE",
      is_advanced: true,
    },
    {
      name: "tertiary_medium",
      hex: "7EBFD7",
      default_hex: "7EBFD7",
      is_advanced: true,
    },
    {
      name: "tertiary",
      hex: "0088cc",
      default_hex: "0088cc",
      is_advanced: false,
    },
    {
      name: "tertiary_high",
      hex: "329ED0",
      default_hex: "329ED0",
      is_advanced: true,
    },
    {
      name: "quaternary",
      hex: "e45735",
      default_hex: "e45735",
      is_advanced: false,
    },
    {
      name: "header_background",
      hex: "FCF6E1",
      default_hex: "FCF6E1",
      is_advanced: false,
    },
    {
      name: "header_primary",
      hex: "002B36",
      default_hex: "002B36",
      is_advanced: false,
    },
    {
      name: "highlight_low",
      hex: "FDF9AD",
      default_hex: "FDF9AD",
      is_advanced: true,
    },
    {
      name: "highlight_medium",
      hex: "E3D0A3",
      default_hex: "E3D0A3",
      is_advanced: true,
    },
    {
      name: "highlight",
      hex: "F2F481",
      default_hex: "F2F481",
      is_advanced: false,
    },
    {
      name: "highlight_high",
      hex: "BCAA7F",
      default_hex: "BCAA7F",
      is_advanced: true,
    },
    {
      name: "selected",
      hex: "E8E6D3",
      default_hex: "E8E6D3",
      is_advanced: false,
    },
    {
      name: "hover",
      hex: "F0EBDA",
      default_hex: "F0EBDA",
      is_advanced: false,
    },
    {
      name: "danger_low",
      hex: "F8D9C2",
      default_hex: "F8D9C2",
      is_advanced: true,
    },
    {
      name: "danger",
      hex: "e45735",
      default_hex: "e45735",
      is_advanced: false,
    },
    {
      name: "success_low",
      hex: "CFE5B9",
      default_hex: "CFE5B9",
      is_advanced: true,
    },
    {
      name: "success_medium",
      hex: "4CB544",
      default_hex: "4CB544",
      is_advanced: true,
    },
    {
      name: "success",
      hex: "009900",
      default_hex: "009900",
      is_advanced: false,
    },
    {
      name: "love_low",
      hex: "FCDDD2",
      default_hex: "FCDDD2",
      is_advanced: true,
    },
    {
      name: "love",
      hex: "fa6c8d",
      default_hex: "fa6c8d",
      is_advanced: false,
    },
  ],
  is_dark: false,
};

module("Integration | Component | ColorPalettePreview", function (hooks) {
  setupRenderingTest(hooks);

  test("renders default color palette", async function (assert) {
    await render(
      <template><ColorPalettePreview class="color-palette-preview" /></template>
    );

    assert.dom(".color-palette-preview").hasStyle(
      {
        "--primary-low--preview": "#e9e9e9",
        "--tertiary-low--preview": "#d1f0ff",
      },
      "fallback styles are applied for default color palette"
    );
  });

  test("renders custom color palette", async function (assert) {
    await render(
      <template>
        <ColorPalettePreview
          @scheme={{example_scheme}}
          class="color-palette-preview"
        />
      </template>
    );

    assert
      .dom(".color-palette-preview")
      .hasStyle(
        Object.fromEntries(
          example_scheme.colors.map((color) => [
            `--${color.name.replaceAll("_", "-")}--preview`,
            "#" + color.hex || color.default_hex,
          ])
        ),
        "custom colors are applied correctly"
      );
  });
});
