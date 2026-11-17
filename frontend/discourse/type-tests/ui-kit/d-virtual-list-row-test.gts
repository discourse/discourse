// Positive type assertions for the row modifiers DVirtualList yields: every
// invocation below must compile. Keep this file free of Glint error directives,
// because one would suppress reporting for the rest of the file. Negatives live
// in d-virtual-list-row-errors-test.gts.
import DVirtualList from "discourse/ui-kit/d-virtual-list";

interface Row {
  id: number;
  label: string;
}

declare const rows: readonly Row[];
declare function estimate(row: Row, index: number): number;

const Positives = <template>
  <DVirtualList
    @as="ul"
    @estimateSize={{estimate}}
    @items={{rows}}
    @ownedRow={{true}}
    as |item row|
  >
    <li {{row.place row.start row.index}} {{row.measure}}>{{item.label}}</li>
  </DVirtualList>
</template>;

export default Positives;
