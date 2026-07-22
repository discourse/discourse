import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import DVirtualList from "discourse/ui-kit/d-virtual-list";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

const ROW_COUNT = 10000;
const ROW_HEIGHT = 44;

export default class VirtualListMolecule extends Component {
  estimateSize = () => ROW_HEIGHT;

  @cached
  get rows() {
    return Array.from({ length: ROW_COUNT }, (_, index) => ({
      index,
      label: `Row ${index + 1}`,
    }));
  }

  get virtualListCode() {
    return `
import DVirtualList from "discourse/ui-kit/d-virtual-list";

// Size the .d-virtual-list viewport via CSS (it is the scroll element);
// @role/@itemRole and any ...attributes land on the inner container.
<template>
  <DVirtualList
    @items={{this.rows}}
    @estimateSize={{this.estimateSize}}
    @role="list"
    @itemRole="listitem"
    as |row|
  >
    <div class="styleguide-virtual-list__row">{{row.label}}</div>
  </DVirtualList>
</template>
    `;
  }

  <template>
    <StyleguideExample @title="<DVirtualList>" @code={{this.virtualListCode}}>
      <div class="styleguide-virtual-list">
        <p class="styleguide-virtual-list__note">
          {{ROW_COUNT}}
          rows backing the list; only the visible window plus overscan is in the
          DOM. Inspect the rows in devtools while scrolling — the node count
          stays flat, and the scrollbar reflects the full list because the inner
          container carries the total height.
        </p>

        <DVirtualList
          @items={{this.rows}}
          @estimateSize={{this.estimateSize}}
          @role="list"
          @itemRole="listitem"
          as |row|
        >
          <div class="styleguide-virtual-list__row">{{row.label}}</div>
        </DVirtualList>
      </div>
    </StyleguideExample>
  </template>
}
