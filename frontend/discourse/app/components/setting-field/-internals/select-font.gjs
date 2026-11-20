import { concat, hash } from "@ember/helper";
import DSelect from "discourse/ui-kit/select/d-select";

/**
 * The class that draws a font's name in that font. The stylesheet gives the body and heading
 * classes of a font the same family, so one class serves both settings.
 */
function fontClass(value) {
  if (!value) {
    return "";
  }
  return `body-font-${String(value).replace(/_/g, "-")}`;
}

/** A font setting's `{ name, value }` choices, sorted by name. */
function sortedFonts(choices) {
  return [...(choices ?? [])].sort((a, b) => a.name.localeCompare(b.name));
}

/**
 * Picks a font setting's font, drawing each name in its own typeface. The held font's class sits
 * on the root, so the closed field and the input share one typeface and nothing shifts when the
 * input takes focus.
 */
const SelectFont = <template>
  <DSelect
    class={{concat "select-font " (fontClass @value)}}
    @disabled={{@disabled}}
    @onChange={{@onChange}}
    @options={{sortedFonts @choices}}
    @texts={{hash ariaLabel=@ariaLabel}}
    @value={{@value}}
    @valueField="value"
  >
    <:option as |option|>
      <span class={{fontClass option.value}}>{{option.label}}</span>
    </:option>
  </DSelect>
</template>;

export default SelectFont;
