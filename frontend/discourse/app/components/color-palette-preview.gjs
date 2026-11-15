import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import SvgSingleColorPalettePlaceholder from "discourse/components/svg/single-color-palette-placeholder";
import { getColorSchemeStyles } from "discourse/lib/color-transformations";
import { HORIZON_THEME_ID } from "discourse/lib/theme-selector";

export default class ColorPalettePreview extends Component {
  get isBuiltInDefault() {
    return (
      this.args.scheme?.is_builtin_default ||
      !this.args.scheme?.colors?.length ||
      false
    );
  }

  get usesTintedSidebar() {
    return this.args.defaultTheme?.id === HORIZON_THEME_ID;
  }

  get backgroundColor() {
    if (!this.usesTintedSidebar) {
      return "var(--header-background--preview, #fff)";
    }

    return this.args.scheme?.is_dark
      ? "oklch(from var(--tertiary--preview, #08c) 10% 0.025 h)"
      : "oklch(from var(--tertiary--preview, #08c) 96% calc(c * 0.125) h)";
  }

  get sidebarColor() {
    return this.usesTintedSidebar
      ? this.backgroundColor
      : "var(--secondary--preview, #fff)";
  }

  get activeItemColor() {
    return this.usesTintedSidebar
      ? "var(--selected--preview, var(--tertiary-low--preview, #d1f0ff))"
      : "var(--primary-low--preview, #e9e9e9)";
  }

  get styles() {
    if (this.isBuiltInDefault) {
      return trustHTML(
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

    return trustHTML(allStyles);
  }

  <template>
    <div style={{this.styles}} ...attributes>
      <SvgSingleColorPalettePlaceholder
        @activeItemColor={{this.activeItemColor}}
        @backgroundColor={{this.backgroundColor}}
        @sidebarColor={{this.sidebarColor}}
        @tintedSidebar={{this.usesTintedSidebar}}
      />
    </div>
  </template>
}
