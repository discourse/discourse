import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ComboboxPatternTests } from "discourse/tests/helpers/aria-patterns/combobox";
import DSelect from "discourse/ui-kit/select/d-select";

const ITEMS = [
  { id: 1, name: "Apple" },
  { id: 2, name: "Banana" },
  { id: 3, name: "Cherry pie" },
];

/** Controlled host, matching how a real consumer (or FormKit) owns the value. */
class Host extends Component {
  @tracked value = this.args.multiple ? [] : null;

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @items={{ITEMS}}
      @value={{this.value}}
      @onChange={{this.onChange}}
      @variant={{@variant}}
      @multiple={{@multiple}}
      @placeholder="Pick one"
      @identifier="apg-select"
    >
      <:selection as |item|>{{item.name}}</:selection>
      <:item as |item|>{{item.name}}</:item>
    </DSelect>
  </template>
}

const SelectOnly = <template><Host @variant="static" /></template>;
const Typeahead = <template><Host @variant="typeahead" /></template>;
const Multi = <template>
  <Host @variant="typeahead" @multiple={{true}} />
</template>;

// Three capabilities are declined below, and each one is a finding rather than a preference:
//
// - `typeToJump` — printable-character type-to-jump on a select-only combobox is a known deferred
//   item (SANDBOX-A11Y-REMEDIATION.md, K1 "typing ⊘").
// - `opensOnHomeEnd` — the opening keys are Enter/Space/ArrowDown/ArrowUp (`d-select.gts:1377`).
//   APG's select-only pattern also opens on Home and End, onto the first and last option. GAP.
// - `closesOnAltArrowUp` — nothing in `DSelect` or `dRovingFocus` reads `altKey`, so Alt+ArrowUp
//   does not close and commit as APG specifies. Note this also means Alt+ArrowDown "opens" only
//   because the modifier is ignored and the plain key is handled — the modifier is untested by
//   construction until this is implemented. GAP.
const KNOWN_GAPS = { opensOnHomeEnd: false, closesOnAltArrowUp: false };

ComboboxPatternTests({
  name: "DSelect select-only",
  renderer: SelectOnly,
  supports: {
    ...KNOWN_GAPS,
    optionCount: ITEMS.length,
    selectOnly: true,
    typeToJump: false,
  },
});

ComboboxPatternTests({
  name: "DSelect typeahead",
  renderer: Typeahead,
  supports: { ...KNOWN_GAPS, optionCount: ITEMS.length, filtering: true },
});

ComboboxPatternTests({
  name: "DSelect multi",
  renderer: Multi,
  supports: {
    ...KNOWN_GAPS,
    optionCount: ITEMS.length,
    filtering: true,
    multiple: true,
  },
});
