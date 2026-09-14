import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import DVirtualList from "discourse/ui-kit/d-virtual-list";

const ROW_COUNT = 5000;

export default class VirtualListVariableExample extends Component {
  /**
   * A single guess for rows whose real heights differ; each is measured on entry.
   * Deliberately near the MEAN rather than above every row, so measurements correct
   * the total in both directions. An estimate above the tallest row would only ever
   * shrink it, and 5000 rows of one-way drift reads as the primitive mis-measuring
   * rather than as an estimate settling.
   */
  estimateSize = () => 60;

  @cached
  get rows() {
    return Array.from({ length: ROW_COUNT }, (_, index) => ({
      id: index,
      label: `Row ${index + 1}`,
      body: "lorem ipsum dolor sit amet ".repeat(((index * 7) % 6) + 1).trim(),
    }));
  }

  <template>
    <DVirtualList
      aria-label="Variable height virtual list"
      @as="ul"
      @estimateSize={{this.estimateSize}}
      @itemRole="listitem"
      @items={{this.rows}}
      @key="id"
      @ownedRow={{true}}
      @role="list"
      as |item row|
    >
      <li
        aria-posinset={{row.posinset}}
        aria-setsize={{row.setSize}}
        class="styleguide-virtual-list__vrow"
        {{row.place row.start row.index}}
        {{row.measure}}
      >
        <strong>{{item.label}}</strong>
        —
        {{item.body}}
      </li>
    </DVirtualList>
  </template>
}
