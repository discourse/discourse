import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import DVirtualList from "discourse/ui-kit/d-virtual-list";

const ROW_COUNT = 5000;

export default class VirtualListVariableExample extends Component {
  /** A single guess for rows whose real heights differ; each is measured on entry. */
  estimateSize = () => 96;

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
      @items={{this.rows}}
      @key="id"
      @as="ul"
      @role="list"
      @itemRole="listitem"
      @ownedRow={{true}}
      @estimateSize={{this.estimateSize}}
      aria-label="Variable height virtual list"
      as |item row|
    >
      <li
        class="styleguide-virtual-list__vrow"
        aria-posinset={{row.posinset}}
        aria-setsize={{row.setSize}}
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
