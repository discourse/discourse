import Component from "@glimmer/component";
import { action } from "@ember/object";
import DSelectList from "discourse/ui-kit/select/d-select-list";
import {
  type ColorPalette,
  paletteGroupBy,
  paletteGroupHeader,
  PaletteOption,
  paletteOptions,
} from "discourse/ui-kit/select/recipes/color-palettes/d-select-color-palette";
import type {
  SelectCoreTexts,
  SelectOptionLike,
  SelectTexts,
  SelectValue,
} from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";

/** The always-open color palette list's arguments. */
interface DSelectColorPaletteListSignature {
  Args: {
    /** The palettes offered, grouped under Light and Dark when the list holds both kinds. */
    palettes?: readonly ColorPalette[];
    /** The palettes in use, marked "Active" whatever the list holds. */
    activeIds?: readonly number[];
    /** The held palette's id. */
    value?: number | null;
    /** Receives the picked palette's id. */
    onChange?: (value: number | null) => void;
    /** Leaves the held palette out of the list, for a page that shows it elsewhere. */
    hideSelected?: boolean;
    /** Call-site customization identity. */
    identifier?: string;
    /** The list's texts, merged over the picker's; see `DSelectList`'s `@texts`. */
    texts?: SelectCoreTexts;
  };
  Element: HTMLElement;
}

/**
 * Picks a color palette from a list that stays open, with a search field above it. Like the
 * field, it groups a mix of light and dark palettes and marks the ones in use "Active".
 */
export default class DSelectColorPaletteList extends Component<DSelectColorPaletteListSignature> {
  /** The picker's texts; the engine's own wording covers the rest. */
  kindTexts: SelectTexts = {
    ariaLabel: () => i18n("color_palette_picker.label"),
  };

  get groupBy() {
    return paletteGroupBy(this.args.palettes ?? []);
  }

  get options(): SelectOptionLike[] {
    return paletteOptions(this.args.palettes ?? [], this.args.activeIds);
  }

  @action
  onChange(value: SelectValue) {
    this.args.onChange?.(typeof value === "number" ? value : null);
  }

  <template>
    <DSelectList
      class="d-select-color-palette-list"
      ...attributes
      @groupBy={{this.groupBy}}
      @groupHeader={{paletteGroupHeader}}
      @hideSelected={{@hideSelected}}
      @identifier={{@identifier}}
      @kind="select-color-palette-list"
      @kindTexts={{this.kindTexts}}
      @multiple={{false}}
      @onChange={{this.onChange}}
      @options={{this.options}}
      @texts={{@texts}}
      @value={{@value}}
    >
      <:option as |option|>
        <PaletteOption @label={{option.label}} @record={{option.record}} />
      </:option>
    </DSelectList>
  </template>
}
