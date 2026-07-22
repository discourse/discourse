import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import type { ModifierLike } from "@glint/template";
import { modifier } from "ember-modifier";
import type { DVirtualListApi } from "discourse/ui-kit/d-virtual-list";
import {
  isVirtualizationEnabled,
  keyFor,
} from "discourse/ui-kit/lib/virtualizer";
import dVirtualizer from "discourse/ui-kit/modifiers/d-virtualizer";

/*
 * SPIKE — THROWAWAY, NOT PRODUCTION.
 *
 * Virtualizes a real `<table>` — the one case the per-row translate layout cannot
 * serve: a `<tr>` can't be `position: absolute` without destroying table layout, so
 * the window is offset with spacer `<tr><td colspan>` rows in normal flow (the
 * spacer technique from `d-virtual-list-spacer-spike`, specialized for a table body).
 *
 * A single `<table>` inside the scroll element, with a `position: sticky` `<thead>`
 * and a virtualized `<tbody>`. The top spacer absorbs the window offset, and the
 * sticky header simply covers the topmost rows (which are still rendered), so no
 * `scrollMargin` correction is needed. `table-layout: fixed` + the shared `<colgroup>`
 * keep column widths stable as the window changes. Reuses the same `dVirtualizer`
 * engine. Note: a table wants DETERMINISTIC row heights — measuring and reflowing a
 * table churns the layout (and virtual-core's ResizeObserver) far more than a plain
 * list, so an accurate `@estimateSize` matters more here.
 */

interface TableVirtualItem {
  key: number | string | bigint;
  index: number;
  start: number;
  size: number;
}

interface TableRow<T> {
  item: T;
  index: number;
  key: number | string | bigint;
  start: number;
  size: number;
  measure: ModifierLike<HTMLElement>;
}

interface DVirtualListTableSpikeSignature<T> {
  Args: {
    items: readonly T[];
    estimateSize: (item: T, index: number) => number;
    key?: string;
    overscan?: number;
    /** Column widths (any CSS width) — shared by the head and body colgroups. */
    columnWidths: string[];
  };
  Blocks: {
    header: [];
    default: [item: T, row: TableRow<T>];
  };
  Element: HTMLElement;
}

export default class DVirtualListTableSpike<T> extends Component<
  DVirtualListTableSpikeSignature<T>
> {
  @tracked api: DVirtualListApi | null = null;

  measureRow = modifier((element: HTMLElement) => {
    this.api?.measureElement(element);
  });

  // The spacer height lives on the `<td>` (a `<tr>` won't reliably grow past its
  // content), standing in for the rows above/below the window.
  spacerHeight = modifier(
    (element: HTMLElement, [height]: [height: number]) => {
      element.style.height = `${height}px`;
    }
  );

  @tracked _virtualItems: TableVirtualItem[] = [];
  @tracked _totalSize = 0;

  // Pre-built trusted widths so each `<col>` style is a bound value rather than
  // string-concatenated in the template.
  get columnStyles() {
    return this.args.columnWidths.map((width) => trustHTML(`width: ${width}`));
  }

  get virtualizationActive() {
    return isVirtualizationEnabled();
  }

  get topSpacerHeight() {
    const first = this._virtualItems[0];
    return first ? first.start : 0;
  }

  get bottomSpacerHeight() {
    const last = this._virtualItems[this._virtualItems.length - 1];
    if (!last) {
      return 0;
    }
    return Math.max(0, this._totalSize - (last.start + last.size));
  }

  get rows(): TableRow<T>[] {
    if (!this.virtualizationActive) {
      return this.args.items.map((item, index) => ({
        item,
        index,
        key: keyFor(item, this.args.key),
        start: 0,
        size: 0,
        measure: this.measureRow,
      }));
    }

    return this._virtualItems.map((vi) => ({
      item: this.args.items[vi.index],
      index: vi.index,
      key: vi.key,
      start: vi.start,
      size: vi.size,
      measure: this.measureRow,
    }));
  }

  @action
  onState(state: {
    virtualItems: TableVirtualItem[];
    totalSize: number;
    range: { startIndex: number; endIndex: number } | null;
  }) {
    this._virtualItems = state.virtualItems;
    this._totalSize = state.totalSize;
  }

  @action
  onRegisterApi(api: DVirtualListApi) {
    this.api = api;
  }

  <template>
    <div
      class="d-virtual-list d-virtual-table"
      {{dVirtualizer
        items=@items
        estimateSize=@estimateSize
        key=@key
        overscan=@overscan
        onState=this.onState
        onRegisterApi=this.onRegisterApi
      }}
      ...attributes
    >
      <table class="d-virtual-table__grid">
        <colgroup>
          {{#each this.columnStyles as |style|}}
            <col style={{style}} />
          {{/each}}
        </colgroup>
        <thead class="d-virtual-table__head">
          <tr>{{yield to="header"}}</tr>
        </thead>
        <tbody>
          {{#if @items.length}}
            {{#if this.virtualizationActive}}
              <tr aria-hidden="true" class="d-virtual-table__spacer">
                <td
                  colspan={{@columnWidths.length}}
                  {{this.spacerHeight this.topSpacerHeight}}
                ></td>
              </tr>
            {{/if}}

            {{#each this.rows key="key" as |row|}}
              <tr data-index={{row.index}} {{row.measure}}>
                {{yield row.item row}}
              </tr>
            {{/each}}

            {{#if this.virtualizationActive}}
              <tr aria-hidden="true" class="d-virtual-table__spacer">
                <td
                  colspan={{@columnWidths.length}}
                  {{this.spacerHeight this.bottomSpacerHeight}}
                ></td>
              </tr>
            {{/if}}
          {{/if}}
        </tbody>
      </table>
    </div>
  </template>
}
