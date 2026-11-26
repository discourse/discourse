import Component from "@glimmer/component";
import type { TemplateOnlyComponent } from "@ember/component/template-only";
import { action } from "@ember/object";
import { type TrustedHTML, trustHTML } from "@ember/template";
import type { ComponentLike } from "@glint/template";
import ColorPalettePreviewComponent from "discourse/components/color-palette-preview";
import DSelect, {
  type DSelectSignature,
} from "discourse/ui-kit/select/d-select";
import type { SelectRecipeArgs } from "discourse/ui-kit/select/recipes/-internals/recipe-args";
import {
  type SelectId,
  selectOption,
  type SelectOptionLike,
  type SelectRecord,
  type SelectTexts,
  type SelectValue,
} from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";

/** A color palette as the call sites hold it. */
export interface ColorPalette extends SelectRecord {
  id: number;
  name: string;
  /** Unset for an entry that stands for another palette, such as "Theme default". */
  is_dark?: boolean;
  colors?: readonly PaletteColor[];
}

/** One of a palette's colors; a color left at its default carries only `default_hex`. */
interface PaletteColor {
  name: string;
  hex?: string;
  default_hex?: string;
}

/** The color palette picker's arguments. */
interface DSelectColorPaletteSignature {
  Args: Pick<
    DSelectSignature["Args"],
    | "ariaLabelledBy"
    | "ariaRequired"
    | "clearMode"
    | "describedBy"
    | "disabled"
    | "icon"
    | "id"
    | "invalid"
    | "noneOption"
    | "texts"
    | "variant"
  > &
    SelectRecipeArgs & {
      /** The palettes offered, in the order they are listed within their group. */
      palettes?: readonly ColorPalette[];
      /** The palettes in use, marked "Active" whatever the field holds. */
      activeIds?: readonly number[];
      /** The held palette's id. */
      value?: number | null;
      /** Receives the picked palette's id, or `null` for the none option. */
      onChange?: (value: number | null) => void;
    };
  Element: HTMLElement;
}

const LIGHT = "light";
const DARK = "dark";

/** The palette preview, which spreads its attributes on a `div`. */
const ColorPalettePreview =
  ColorPalettePreviewComponent as unknown as ComponentLike<{
    Args: { scheme: ColorPalette };
    Element: HTMLDivElement;
  }>;

function groupOf(record: SelectRecord): string | undefined {
  const { is_dark } = record as ColorPalette;
  if (is_dark == null) {
    return undefined;
  }
  return is_dark ? DARK : LIGHT;
}

/** The colors a strip shows, in order: the page, its text, links and buttons, selected items. */
const SWATCH_COLORS = ["secondary", "primary", "tertiary", "selected"] as const;

/**
 * The background style of each square in a palette's strip: all four, so the squares line up
 * across palettes, or none when the palette lacks one.
 */
function swatchesOf(record: SelectRecord): TrustedHTML[] {
  const hexes = new Map(
    (paletteOf(record).colors ?? []).map((color) => [
      color.name,
      (color.hex || color.default_hex || "").replace(/[^0-9a-f]/gi, ""),
    ])
  );
  if (SWATCH_COLORS.some((name) => !hexes.get(name))) {
    return [];
  }
  return SWATCH_COLORS.map((name) =>
    trustHTML(`background-color: #${hexes.get(name)}`)
  );
}

/** A record's own fields, for the blocks. */
function paletteOf(record: SelectRecord): ColorPalette {
  return record as ColorPalette;
}

/** A palette's strip of color squares, for sighted readers only; nothing when it has none. */
const PaletteSwatches: TemplateOnlyComponent<{
  Args: { record: SelectRecord };
}> = <template>
  {{#let (swatchesOf @record) as |swatches|}}
    {{#if swatches.length}}
      <span aria-hidden="true" class="d-select-color-palette__swatches">
        {{#each swatches as |swatch|}}
          <span class="d-select-color-palette__swatch" style={{swatch}}></span>
        {{/each}}
      </span>
    {{/if}}
  {{/let}}
</template>;

/** A palette's row: its preview, its name and its strip, with a badge over the preview if given. */
export const PaletteOption: TemplateOnlyComponent<{
  Args: { badge?: string; label: string; record: SelectRecord };
}> = <template>
  <span class="d-select-color-palette__option">
    {{#if @badge}}
      <span class="d-select-color-palette__badge">{{@badge}}</span>
    {{/if}}
    <ColorPalettePreview
      class="d-select-color-palette__preview"
      @scheme={{paletteOf @record}}
    />
    <span class="d-select-color-palette__details">
      <span class="d-select-color-palette__name">{{@label}}</span>
      <PaletteSwatches @record={{@record}} />
    </span>
  </span>
</template>;

/** Whether the palettes hold both light and dark ones, and so are grouped. */
function mixesLightAndDark(palettes: readonly ColorPalette[]): boolean {
  const groups = new Set(palettes.map(groupOf));
  return groups.has(LIGHT) && groups.has(DARK);
}

/** Groups palettes by mode when they mix light and dark ones; nothing otherwise. */
export function paletteGroupBy(
  palettes: readonly ColorPalette[]
): typeof groupOf | undefined {
  return mixesLightAndDark(palettes) ? groupOf : undefined;
}

/** Heads the light and dark groups; palettes with no mode get no header. */
export function paletteGroupHeader(key: SelectId): string | undefined {
  if (key === DARK) {
    return i18n("color_palette_picker.dark");
  }
  if (key === LIGHT) {
    return i18n("color_palette_picker.light");
  }
}

/** The palettes as options: light ones before dark when mixed, the in-use ones described so. */
export function paletteOptions(
  palettes: readonly ColorPalette[],
  activeIds: readonly number[] = []
): SelectOptionLike[] {
  const rank = (palette: ColorPalette) =>
    [undefined, LIGHT, DARK].indexOf(groupOf(palette));
  const ordered = mixesLightAndDark(palettes)
    ? [...palettes].sort((a, b) => rank(a) - rank(b))
    : palettes;
  return ordered.map((palette) =>
    activeIds.includes(palette.id)
      ? selectOption(palette, {
          description: i18n("user.color_schemes.picker.active"),
        })
      : palette
  );
}

/**
 * Picks a color palette, drawing each one's colors beside its name. A list holding both light and
 * dark palettes is grouped under "Light" and "Dark"; the palettes in use are marked "Active".
 */
export default class DSelectColorPalette extends Component<DSelectColorPaletteSignature> {
  /** The picker's texts; the engine's own wording covers the rest. */
  kindTexts: SelectTexts = {
    ariaLabel: () => i18n("color_palette_picker.label"),
  };

  get groupBy() {
    return paletteGroupBy(this.#palettes);
  }

  get legacyKind() {
    return this.args.legacyKind ?? "color-palette-picker";
  }

  get options(): SelectOptionLike[] {
    return paletteOptions(this.#palettes, this.args.activeIds);
  }

  get #palettes(): readonly ColorPalette[] {
    return this.args.palettes ?? [];
  }

  @action
  onChange(value: SelectValue) {
    this.args.onChange?.(typeof value === "number" ? value : null);
  }

  <template>
    <DSelect
      ...attributes
      @ariaLabelledBy={{@ariaLabelledBy}}
      @ariaRequired={{@ariaRequired}}
      @clearMode={{@clearMode}}
      @describedBy={{@describedBy}}
      @disabled={{@disabled}}
      @groupBy={{this.groupBy}}
      @groupHeader={{paletteGroupHeader}}
      @icon={{@icon}}
      @id={{@id}}
      @identifier={{@identifier}}
      @instanceContext={{@instanceContext}}
      @invalid={{@invalid}}
      @kind="select-color-palette"
      @kindTexts={{this.kindTexts}}
      @legacyKind={{this.legacyKind}}
      @noneOption={{@noneOption}}
      @onChange={{this.onChange}}
      @options={{this.options}}
      @texts={{@texts}}
      @value={{@value}}
      @variant={{@variant}}
    >
      <:option as |option|>
        <PaletteOption @label={{option.label}} @record={{option.record}} />
      </:option>
      <:selection as |option|>
        <span class="d-select-color-palette__selection">
          <ColorPalettePreview
            class="d-select-color-palette__preview --mini"
            @scheme={{paletteOf option.record}}
          />
          <span class="d-select-color-palette__name">{{option.label}}</span>
          <PaletteSwatches @record={{option.record}} />
        </span>
      </:selection>
    </DSelect>
  </template>
}
