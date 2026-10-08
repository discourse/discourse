// Negative type assertions for the row modifiers DVirtualList yields: every
// invocation below must fail to compile. They are quarantined here because a
// Glint error directive suppresses reporting elsewhere in its file, which would
// let a positive pass against a broken declaration. Positives live in
// d-virtual-list-row-test.gts.
import DVirtualList from "discourse/ui-kit/d-virtual-list";

interface Row {
  id: number;
  label: string;
}

declare const rows: readonly Row[];
declare function estimate(row: Row, index: number): number;

const Negatives = <template>
  <DVirtualList
    @estimateSize={{estimate}}
    @items={{rows}}
    @ownedRow={{true}}
    as |item row|
  >
    {{! @glint-expect-error - measure takes no arguments }}
    <div {{row.measure "extra"}}>{{item.label}}</div>

    {{! @glint-expect-error - measure needs an HTML element to size }}
    <svg {{row.measure}}><title>{{item.label}}</title></svg>
  </DVirtualList>
</template>;

export default Negatives;
