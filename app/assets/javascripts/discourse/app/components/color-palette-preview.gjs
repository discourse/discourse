import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";
import SvgSingleColorPalettePlaceholder from "discourse/components/svg/single-color-palette-placeholder";
import { getColorSchemeStyles } from "discourse/lib/color-transformations";

export default class ColorPalettePreview extends Component {
  get isBuiltInDefault() {
    return (
      this.args.scheme?.is_builtin_default ||
      !this.args.scheme?.colors?.length ||
      false
    );
  }

  get styles() {
    if (this.isBuiltInDefault) {
      return htmlSafe(
        "--primary-low--preview: #e9e9e9; --tertiary-low--preview: #d1f0ff;"
      );
    }

    // generate primary-low and tertiary-low
    const existingStyles = getColorSchemeStyles(this.args.scheme);

    // create variables from scheme.colors
    const colorVariables =
      this.args.scheme?.colors
        ?.map((color) => {
          let hex = color.hex || color.default_hex;

          if (hex && !hex.startsWith("#")) {
            hex = `#${hex}`;
          }

          const name = color.name.replaceAll("_", "-");

          return `--${name}--preview: ${hex}`;
        })
        .join("; ") || "";

    const allStyles = colorVariables
      ? `${existingStyles} ${colorVariables};`
      : existingStyles;

    return htmlSafe(allStyles);
  }

  <template>
    <div style={{this.styles}} ...attributes>
      <SvgSingleColorPalettePlaceholder />
    </div>
  </template>
}
