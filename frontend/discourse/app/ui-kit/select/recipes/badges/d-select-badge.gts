import type { TemplateOnlyComponent } from "@ember/component/template-only";
import dIconOrImage from "discourse/ui-kit/helpers/d-icon-or-image";
import DSelect, {
  type DSelectSignature,
} from "discourse/ui-kit/select/d-select";
import type { SelectRecipeArgs } from "discourse/ui-kit/select/recipes/-internals/recipe-args";
import {
  recordOf,
  selectOption,
  type SelectOptionLike,
  type SelectRecord,
} from "discourse/ui-kit/select/select-engine";

/** The badge picker's arguments. */
interface DSelectBadgeSignature {
  Args: Pick<
    DSelectSignature["Args"],
    | "ariaLabelledBy"
    | "clearable"
    | "describedBy"
    | "disabled"
    | "id"
    | "noneOption"
    | "texts"
    | "variant"
  > &
    SelectRecipeArgs & {
      /** Shows each badge's description, as plain text, under its name. */
      descriptions?: boolean;
      /** The badges offered, as badge records or options of them. */
      options?: SelectOptionLike[];
      /** The held badge's id. */
      value?: number | null;
      /** Receives the picked badge's id, or `null` for the none option. */
      onChange?: (badgeId: number | null) => void;
    };
  Element: HTMLElement;
}

/** Long enough for a sentence or two; the server allows 500 characters. */
const DESCRIPTION_LIMIT = 200;

/**
 * A badge's description as plain text, cut short when long. Descriptions may hold markup, which
 * is parsed into a template so nothing in it loads or runs.
 */
function descriptionOf(badge: object): string | undefined {
  const { description } = badge as { description?: unknown };
  if (typeof description !== "string") {
    return;
  }
  const template = document.createElement("template");
  template.innerHTML = description;
  const text = template.content.textContent?.replace(/\s+/g, " ").trim();
  if (!text) {
    return;
  }
  return text.length > DESCRIPTION_LIMIT
    ? `${text.slice(0, DESCRIPTION_LIMIT).trimEnd()}…`
    : text;
}

/** The offered badges, each given its description when they are asked for. */
function withDescriptions(
  options: SelectOptionLike[] | undefined,
  descriptions: boolean | undefined
): SelectOptionLike[] | undefined {
  if (!descriptions || !options) {
    return options;
  }
  return options.map((option) =>
    selectOption(option, { description: descriptionOf(recordOf(option)) })
  );
}

/** A badge record's icon and image, narrowed for `dIconOrImage`. */
function glyphOf(badge: SelectRecord): { icon?: string; image?: string } {
  return {
    icon: typeof badge.icon === "string" ? badge.icon : undefined,
    image: typeof badge.image_url === "string" ? badge.image_url : undefined,
  };
}

/** Hands the caller the picked badge's id; the select's value type is wider than a badge's. */
function emitBadgeId(onChange?: (badgeId: number | null) => void) {
  return onChange && ((value: unknown) => onChange(value as number | null));
}

/**
 * A badge's image, or else its icon. Drawn by the recipe rather than the select, because the
 * select has no notion of an image; both are sized by `--d-select-glyph-size`.
 */
const BadgeGlyph: TemplateOnlyComponent<{ Args: { badge: SelectRecord } }> =
  <template>
    {{~#let (glyphOf @badge) as |glyph|~}}
      {{~#if (or glyph.image glyph.icon)~}}
        <span class="d-select__glyph">{{dIconOrImage glyph}}</span>
      {{~/if~}}
    {{~/let~}}
  </template>;

/**
 * Picks one badge from a list the caller already holds, drawing its image or icon. Unlike other
 * recipes it takes no `:option` or `:selection` block: drawing every badge the same way is its
 * purpose.
 */
const DSelectBadge: TemplateOnlyComponent<DSelectBadgeSignature> = <template>
  <DSelect
    ...attributes
    @ariaLabelledBy={{@ariaLabelledBy}}
    @clearable={{@clearable}}
    @describedBy={{@describedBy}}
    @disabled={{@disabled}}
    @id={{@id}}
    @identifier={{@identifier}}
    @instanceContext={{@instanceContext}}
    @kind="select-badge"
    @legacyKind={{@legacyKind}}
    @noneOption={{@noneOption}}
    @onChange={{emitBadgeId @onChange}}
    @options={{withDescriptions @options @descriptions}}
    @texts={{@texts}}
    @value={{@value}}
    @variant={{@variant}}
  >
    <:option as |option|>
      <BadgeGlyph @badge={{option.record}} />
      {{~option.label~}}
    </:option>
    <:selection as |option|>
      <BadgeGlyph @badge={{option.record}} />
      {{~option.label~}}
    </:selection>
  </DSelect>
</template>;

export default DSelectBadge;
