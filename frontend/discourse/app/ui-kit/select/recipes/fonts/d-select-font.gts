import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import DSelect, {
  type DSelectSignature,
} from "discourse/ui-kit/select/d-select";
import type { SelectRecipeArgs } from "discourse/ui-kit/select/recipes/-internals/recipe-args";
import type {
  SelectOptionLike,
  SelectRecord,
  SelectTexts,
  SelectValue,
} from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";

/** A font as a font setting lists it. */
export interface Font extends SelectRecord {
  /** The font's key, such as `times_new_roman`, unless `valueField` names another field. */
  value?: string;
  name: string;
}

/** The font picker's arguments. */
interface DSelectFontSignature {
  Args: Pick<
    DSelectSignature["Args"],
    | "ariaLabelledBy"
    | "clearable"
    | "contentClass"
    | "describedBy"
    | "disabled"
    | "id"
    | "invalid"
    | "required"
    | "texts"
    | "valueField"
    | "variant"
  > &
    SelectRecipeArgs & {
      /** The fonts offered. */
      fonts?: readonly Font[];
      /**
       * Lists the fonts by name, the default. `false` keeps the order given, for a caller that
       * puts the common ones first.
       */
      sortByName?: boolean;
      /** The held font's key. */
      value?: string | null;
      /** Receives the picked font's key, or `null` when the field is emptied. */
      onChange?: (value: string | null) => void;
    };
  Element: HTMLElement;
}

/**
 * The class that draws a font's name in that font. The stylesheet gives the body and heading
 * classes of a font the same family, so one class serves both.
 */
function fontClass(value: unknown): string {
  if (!value) {
    return "";
  }
  return `body-font-${String(value).replace(/_/g, "-")}`;
}

/**
 * Picks a font, drawing each name in its own typeface. The held font's class sits on the root, so
 * the closed field and the input share one typeface and nothing shifts when the input takes focus.
 */
export default class DSelectFont extends Component<DSelectFontSignature> {
  /** The picker's texts; the engine's own wording covers the rest. */
  kindTexts: SelectTexts = {
    ariaLabel: () => i18n("font_picker.label"),
  };

  get legacyKind() {
    return this.args.legacyKind ?? "font-selector";
  }

  get options(): SelectOptionLike[] {
    const fonts = [...(this.args.fonts ?? [])];
    if (this.args.sortByName === false) {
      return fonts;
    }
    return fonts.sort((a, b) => a.name.localeCompare(b.name));
  }

  @action
  onChange(value: SelectValue) {
    this.args.onChange?.(typeof value === "string" ? value : null);
  }

  <template>
    <DSelect
      class={{concat "d-select-font " (fontClass @value)}}
      ...attributes
      @ariaLabelledBy={{@ariaLabelledBy}}
      @clearable={{@clearable}}
      @contentClass={{@contentClass}}
      @describedBy={{@describedBy}}
      @disabled={{@disabled}}
      @id={{@id}}
      @identifier={{@identifier}}
      @instanceContext={{@instanceContext}}
      @invalid={{@invalid}}
      @kind="select-font"
      @kindTexts={{this.kindTexts}}
      @legacyKind={{this.legacyKind}}
      @onChange={{this.onChange}}
      @options={{this.options}}
      @required={{@required}}
      @texts={{@texts}}
      @value={{@value}}
      @valueField={{if @valueField @valueField "value"}}
      @variant={{@variant}}
    >
      <:option as |option|>
        <span class={{fontClass option.value}}>{{option.label}}</span>
      </:option>
    </DSelect>
  </template>
}
