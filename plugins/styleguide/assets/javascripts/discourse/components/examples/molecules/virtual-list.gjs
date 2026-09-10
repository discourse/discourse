/* The listbox that contains these options is rendered by DVirtualList from
   `@role`, so the rule cannot see it from inside this block. */
/* eslint-disable ember/template-require-context-role */
import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
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
   *
   * Undefined until the first window is published. Collapsing that into "outside"
   * would state a positive fact about pinning from an absence of measurement.
   */
  get selectionInVisibleRange() {
    const range = this.visibleRange;
    if (range == null) {
      return undefined;
    }
    return (
      this.selectedIndex >= range.startIndex &&
      this.selectedIndex <= range.endIndex
    );
  }

  /** The selected row's 1-based label, so the readout and the rows agree. */
  get selectedLabel() {
    return this.rows[this.selectedIndex]?.label ?? "none";
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
      <DButton
        @action={{this.reselect}}
        @translatedLabel="Re-select a random row"
      />
      <DButton
        @action={{this.scrollToSelection}}
        @translatedLabel="Scroll to selection"
      />
      <span class="styleguide-virtual-list__status">
        {{this.selectedLabel}}
        —
        {{#if this.visibleRange}}
          {{#if this.selectionInVisibleRange}}
            inside the visible range
          {{else}}
            outside the visible range, still mounted
          {{/if}}
          (rendering rows
          {{this.visibleRange.startIndex}}–{{this.visibleRange.endIndex}}
          of
          {{this.rows.length}})
        {{else}}
          measuring
        {{/if}}
      </span>
    </div>

    <DVirtualList
      aria-label="Virtual list"
      @as="ul"
      @estimateSize={{this.estimateSize}}
      @initialAlign="center"
      @initialIndex={{this.selectedIndex}}
      @itemRole="option"
      @items={{this.rows}}
      @key="id"
      @onRegisterApi={{this.registerApi}}
      @onVisibleRangeChange={{this.trackRange}}
      @ownedRow={{true}}
      @pinnedIndices={{this.selectedPins}}
      @role="listbox"
      as |item row|
    >

      <li
        aria-posinset={{row.posinset}}
        aria-selected={{if (eq row.index this.selectedIndex) "true" "false"}}
        aria-setsize={{row.setSize}}
        class="styleguide-virtual-list__row
          {{if
            (eq row.index this.selectedIndex)
            'styleguide-virtual-list__row--selected'
          }}"
        role="option"
        {{row.place row.start row.index}}
        {{row.measure}}
      >
        {{item.label}}
      </li>
    </DVirtualList>
  </template>
}
