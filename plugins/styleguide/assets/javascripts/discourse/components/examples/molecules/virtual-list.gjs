/* The listbox that contains these options is rendered by DVirtualList from
   `@role`, so the rule cannot see it from inside this block. */
/* eslint-disable ember/template-require-context-role */
import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { eq } from "discourse/truth-helpers";
import DVirtualList from "discourse/ui-kit/d-virtual-list";

const ROW_COUNT = 5000;
const ROW_HEIGHT = 44;

export default class VirtualListExample extends Component {
  @tracked selectedIndex = 2500;
  @tracked visibleRange = null;

  estimateSize = () => ROW_HEIGHT;
  api = null;

  @cached
  get rows() {
    return Array.from({ length: ROW_COUNT }, (_, index) => ({
      id: index,
      label: `Row ${index + 1}`,
    }));
  }

  /**
   * A fresh function whenever the selection changes, because function identity is
   * what re-triggers the window, and pure over that captured value, because the
   * engine calls it outside any tracking frame. Cached so that identity tracks the
   * selection rather than changing on every read, which is the point being shown.
   */
  @cached
  get selectedPins() {
    const selectedIndex = this.selectedIndex;
    return () => (selectedIndex == null ? [] : [selectedIndex]);
  }

  /**
   * Whether the selected row falls inside the VISIBLE range. Outside it the row
   * may still be mounted because of overscan; only beyond that does keeping it
   * mounted demonstrate `@pinnedIndices`.
   */
  get selectionInVisibleRange() {
    const range = this.visibleRange;
    return (
      range != null &&
      this.selectedIndex >= range.startIndex &&
      this.selectedIndex <= range.endIndex
    );
  }

  @action
  registerApi(api) {
    this.api = api;
  }

  @action
  trackRange(range) {
    this.visibleRange = range;
  }

  @action
  reselect() {
    this.selectedIndex = Math.floor(Math.random() * ROW_COUNT);
  }

  @action
  scrollToSelection() {
    this.api?.scrollToIndex(this.selectedIndex, { align: "center" });
  }

  <template>
    <div class="styleguide-virtual-list__controls">
      <button type="button" {{on "click" this.reselect}}>
        Re-select a random row
      </button>
      <button type="button" {{on "click" this.scrollToSelection}}>
        Scroll to selection
      </button>
      <span class="styleguide-virtual-list__status">
        Selected row #{{this.selectedIndex}}
        —
        {{#if this.selectionInVisibleRange}}
          inside the visible range
        {{else}}
          outside the visible range, still mounted
        {{/if}}
      </span>
    </div>

    <DVirtualList
      @items={{this.rows}}
      @key="id"
      @as="ul"
      @role="listbox"
      @itemRole="option"
      @ownedRow={{true}}
      @estimateSize={{this.estimateSize}}
      @initialIndex={{this.selectedIndex}}
      @initialAlign="center"
      @pinnedIndices={{this.selectedPins}}
      @onVisibleRangeChange={{this.trackRange}}
      @onRegisterApi={{this.registerApi}}
      aria-label="Virtual list"
      as |item row|
    >

      <li
        class="styleguide-virtual-list__row
          {{if
            (eq row.index this.selectedIndex)
            'styleguide-virtual-list__row--selected'
          }}"
        role="option"
        aria-selected={{if (eq row.index this.selectedIndex) "true" "false"}}
        aria-posinset={{row.posinset}}
        aria-setsize={{row.setSize}}
        {{row.place row.start row.index}}
        {{row.measure}}
      >
        {{item.label}}
      </li>
    </DVirtualList>
  </template>
}
