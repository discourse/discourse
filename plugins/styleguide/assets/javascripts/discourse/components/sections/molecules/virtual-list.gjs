import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { eq } from "discourse/truth-helpers";
import DVirtualList from "discourse/ui-kit/d-virtual-list";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

const ROW_COUNT = 50000;
const ROW_HEIGHT = 44;

export default class VirtualListMolecule extends Component {
  @tracked selectedIndex = 25000;
  @tracked visibleRange = null;

  estimateSize = () => ROW_HEIGHT;
  // A rough middle guess for the variable-height rows; real heights are measured.
  variableEstimate = () => 96;
  api = null;

  @cached
  get rows() {
    return Array.from({ length: ROW_COUNT }, (_, index) => ({
      id: index,
      label: `Row ${index + 1}`,
    }));
  }

  // Rows whose intrinsic height varies (wrapped text of a deterministic, varying
  // length) while `estimateSize` guesses a single line. Every row entering the
  // window therefore re-measures, so each row repositions with its own
  // `transform: translateY` on the compositor rather than reflowing its siblings.
  @cached
  get variableRows() {
    return Array.from({ length: ROW_COUNT }, (_, index) => ({
      id: index,
      label: `Row ${index + 1}`,
      body: "lorem ipsum dolor sit amet ".repeat(((index * 7) % 24) + 1).trim(),
    }));
  }

  // Whether the pinned/selected row currently falls inside the rendered window. When
  // false the row is scrolled off-screen yet still in the DOM — which is exactly what
  // `@pinnedIndex` guarantees, so a keyboard cursor on it never dangles.
  get pinnedInView() {
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

  get pinnedCode() {
    return `
import DVirtualList from "discourse/ui-kit/d-virtual-list";

// @initialIndex opens the list already scrolled to the selection (first render only,
// so a later @items change never re-fights the user). @pinnedIndex keeps that row
// mounted even when it scrolls out of the window, merged in ascending DOM order, so
// aria-activedescendant can point at it without it ever unmounting.
<template>
  <DVirtualList
    @items={{this.rows}}
    @key="id"
    @estimateSize={{this.estimateSize}}
    @role="listbox"
    @itemRole="option"
    @initialIndex={{this.selectedIndex}}
    @initialAlign="center"
    @pinnedIndex={{this.selectedIndex}}
    @onVisibleRangeChange={{this.trackRange}}
    @onRegisterApi={{this.registerApi}}
    as |item row|
  >
    <div class={{if (eq row.index this.selectedIndex) "is-selected"}}>
      {{item.label}}
    </div>
  </DVirtualList>
</template>
    `;
  }

  <template>
    <StyleguideExample
      @title="<DVirtualList> — per-row translate, with @pinnedIndex + @initialIndex"
      @code={{this.pinnedCode}}
    >
      <div class="styleguide-virtual-list">
        <p class="styleguide-virtual-list__note">
          {{ROW_COUNT}}
          rows; only the visible window plus overscan is in the DOM. The list
          opens scrolled to the selected row (@initialIndex). Scroll away from
          it and inspect the DOM: the selected row keeps its
          <code>[data-index]</code>
          element mounted (@pinnedIndex) so a keyboard cursor on it never points
          at a removed node.
        </p>

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
            {{#if this.pinnedInView}}
              visible in the window
            {{else}}
              scrolled off-screen, still retained in the DOM
            {{/if}}
          </span>
        </div>

        <DVirtualList
          @items={{this.rows}}
          @key="id"
          @estimateSize={{this.estimateSize}}
          @role="listbox"
          @itemRole="option"
          @initialIndex={{this.selectedIndex}}
          @initialAlign="center"
          @pinnedIndex={{this.selectedIndex}}
          @onVisibleRangeChange={{this.trackRange}}
          @onRegisterApi={{this.registerApi}}
          aria-label="Pinned virtual list"
          as |item row|
        >
          <div
            class="styleguide-virtual-list__row
              {{if
                (eq row.index this.selectedIndex)
                'styleguide-virtual-list__row--selected'
              }}"
          >
            {{item.label}}
          </div>
        </DVirtualList>
      </div>
    </StyleguideExample>

    <StyleguideExample
      @title="Variable-height rows — per-row translate (positions on the COMPOSITOR)"
    >
      <div class="styleguide-virtual-list styleguide-virtual-list--tall">
        <p class="styleguide-virtual-list__note">
          {{ROW_COUNT}}
          rows that re-measure as they enter the window (each has a different
          wrapped height; the estimate is a single guess). Per-row translate
          repositions rows with
          <code>transform: translateY</code>, handled on the compositor thread —
          no reflow. Scroll fast: it stays smooth.
        </p>

        <DVirtualList
          @items={{this.variableRows}}
          @key="id"
          @estimateSize={{this.variableEstimate}}
          @role="list"
          @itemRole="listitem"
          as |item|
        >
          <div class="styleguide-virtual-list__vrow">
            <strong>{{item.label}}</strong>
            —
            {{item.body}}
          </div>
        </DVirtualList>
      </div>
    </StyleguideExample>
  </template>
}
