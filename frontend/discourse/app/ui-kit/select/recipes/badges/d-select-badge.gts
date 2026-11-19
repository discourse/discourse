import type { TemplateOnlyComponent } from "@ember/component/template-only";
import dIconOrImage from "discourse/ui-kit/helpers/d-icon-or-image";
import DSelect, {
  type DSelectSignature,
} from "discourse/ui-kit/select/d-select";
import type { SelectRecipeArgs } from "discourse/ui-kit/select/recipes/-internals/recipe-args";
import type {
  SelectOptionLike,
  SelectRecord,
} from "discourse/ui-kit/select/select-engine";

/** The badge picker's arguments. */
interface DSelectBadgeSignature {
  Args: Pick<
    DSelectSignature["Args"],
    | "ariaLabelledBy"
    | "describedBy"
    | "disabled"
    | "id"
    | "noneOption"
    | "texts"
    | "variant"
  > &
    SelectRecipeArgs & {
      /** The badges offered, as badge records or options of them. */
      options?: SelectOptionLike[];
      /** The held badge's id. */
      value?: number | null;
      /** Receives the picked badge's id, or `null` for the none option. */
      onChange?: (badgeId: number | null) => void;
    };
  Element: HTMLElement;
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
 * select has no notion of an image; both are sized by `--d-select-badge-glyph-size`.
 */
const BadgeGlyph: TemplateOnlyComponent<{ Args: { badge: SelectRecord } }> =
  <template>
    {{#let (glyphOf @badge) as |glyph|}}
      {{#if (or glyph.image glyph.icon)}}
        <span class="d-select-badge__glyph">{{dIconOrImage glyph}}</span>
      {{/if}}
    {{/let}}
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
    @describedBy={{@describedBy}}
    @disabled={{@disabled}}
    @id={{@id}}
    @identifier={{@identifier}}
    @instanceContext={{@instanceContext}}
    @kind="select-badge"
    @legacyKind={{@legacyKind}}
    @noneOption={{@noneOption}}
    @onChange={{emitBadgeId @onChange}}
    @options={{@options}}
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
