import { makeArray } from "discourse/lib/helpers";
import { applyValueTransformer } from "discourse/lib/transformer";
import type SelectOptionsView from "discourse/ui-kit/select/-internals/engine/select-options";
import type {
  SelectDescriptor,
  SelectItem,
  SelectItemId,
  SelectSnapshot,
  SelectValue,
} from "discourse/ui-kit/select/select-engine";

export default class ListComposer {
  #options: SelectOptionsView;
  #getFilter: () => string;
  #getValue: () => SelectValue;
  #getHasValue: () => boolean;
  #isSelected: (item: SelectItem) => boolean;
  #getAtMaximum: () => boolean;
  #getTotal: () => number | undefined;
  #applyLegacyContent: (items: SelectItem[]) => SelectItem[];

  constructor(opts: {
    options: SelectOptionsView;
    getFilter: () => string;
    getValue: () => SelectValue;
    getHasValue: () => boolean;
    isSelected: (item: SelectItem) => boolean;
    getAtMaximum: () => boolean;
    getTotal: () => number | undefined;
    applyLegacyContent: (items: SelectItem[]) => SelectItem[];
  }) {
    this.#options = opts.options;
    this.#getFilter = opts.getFilter;
    this.#getValue = opts.getValue;
    this.#getHasValue = opts.getHasValue;
    this.#isSelected = opts.isSelected;
    this.#getAtMaximum = opts.getAtMaximum;
    this.#getTotal = opts.getTotal;
    this.#applyLegacyContent = opts.applyLegacyContent;
  }

  /**
   * Builds the final rendered item list from the source's resolved items: applies
   * plugin `select-content` transformers, groups the options, appends the create-on-the-fly
   * item, and prepends any special items.
   *
   * @param rawItems - The items resolved by the source.
   * @returns The frozen list of normalized descriptors to render.
   */
  buildItems(rawItems: SelectItem[] = []): readonly SelectDescriptor[] {
    let items: SelectItem[] = [...(makeArray(rawItems) as SelectItem[])];

    items = applyValueTransformer("select-content", items, {
      identifiers: this.#options.identifiers,
      filter: this.#getFilter(),
      value: this.#getValue(),
    });

    // Legacy `modifySelectKit(id).{prepend,append,replace}Content` extensions run in
    // their own stage, after the native transformer, so ordering is deterministic and
    // does not depend on global transformer registration order.
    items = this.#applyLegacyContent(items);

    // The option count never includes structural rows (headers/dividers), whether they come
    // from grouping below or an upstream injector.
    const sourceCount = items.filter(
      (item) => !this.#isStructural(item)
    ).length;

    const createItem = this.#shouldOfferCreate(items)
      ? // `#shouldOfferCreate` already guaranteed a `createItem` is present.
        this.#options.createItem!(this.#getFilter())
      : null;

    // Group the source options before appending create, so the create row is never grouped
    // and headers never enter the option count.
    const grouped = this.#shouldGroup() ? this.#groupItems(items) : items;

    const noneRow = this.#noneRow();
    const consumerSpecial = makeArray(
      this.#options.specialItems?.(this.#snapshot()) ?? []
    ) as SelectItem[];
    // The none row leads the specials so it is the first option (Home lands on it) and flows
    // through the same counting path below, keeping its `posInSet`/`setSize`/`logicalIndex` in
    // lockstep with the rest of the set.
    const specialItems = noneRow
      ? [noneRow, ...consumerSpecial]
      : consumerSpecial;
    const finalItems = createItem
      ? [...specialItems, ...grouped, createItem]
      : [...specialItems, ...grouped];

    // Only option rows count toward the set; a special that is itself structural (a seam
    // escape hatch) is prepended but never numbered.
    const specialCount = specialItems.filter(
      (item) => !this.#isStructural(item)
    ).length;

    // Normalize as the final step: everything above operates on raw items (so the
    // transformer / bridge / onSelect pipeline is unchanged); only the render array is wrapped.
    return this.#describeList(
      finalItems,
      specialCount,
      sourceCount,
      createItem ? 1 : 0
    );
  }

  /**
   * Normalizes arbitrary items into the frozen descriptor shape used for rendering.
   *
   * @param items - The items to normalize.
   */
  describeItems(items: SelectItem[]): readonly SelectDescriptor[] {
    return Object.freeze(
      // Never cap-disabled: these describe the held selection for the trigger, and the cap only
      // ever closes off rows that are *not* selected.
      items.map((item, index) => this.#normalize(item, index, false))
    );
  }

  /**
   * Normalizes the list rows — specials, then source rows (with any injected group headers),
   * then create — and stamps each OPTION with its position in the whole result set. Positions
   * come from the engine's own totals rather than the DOM index, so they stay correct while
   * only a window is mounted, and they count options only: an interleaved header/divider
   * shifts no option's `posInSet` and never enters `setSize`.
   */
  #describeList(
    items: SelectItem[],
    specialCount: number,
    sourceCount: number,
    createCount: number
  ): readonly SelectDescriptor[] {
    const total = this.#getTotal();
    // `aria-setsize` describes the complete set rather than the rendered rows, so a source that
    // declares its total has already answered; withholding it until the last page lands would
    // report "unknown" about something known.
    //
    // A source that declares no total is sized by what it has loaded, never by `-1`. That sentinel
    // is unusable in practice: no two engines interpret it alike, and its own AAM tells user agents
    // to substitute 1. The loaded rows are the ones the reader can reach anyway, and "there is
    // more" is carried by the announcements that can express it.
    //
    // The floor keeps a transformer or the legacy bridge, which can add rows absent from a reported
    // total, from pushing a position past the set.
    const sourceTotal = Math.max(total ?? sourceCount, sourceCount);
    const setSize = specialCount + sourceTotal + createCount;

    // Loaded source rows are a prefix, so their positions hold whatever sizes the set.
    const lastOptionOrdinal = specialCount + sourceCount;

    // Hoisted: the cap is a property of the selection, not of a row, and `#atMaximum` reads the
    // deduped value array — so evaluating it per row would repeat that work for every option.
    const atMaximum = this.#getAtMaximum();

    let optionOrdinal = 0;
    let logicalIndex = 0;
    let nextGroupOrdinal = 0;
    let currentGroupOrdinal: number | undefined;
    return Object.freeze(
      items.map((item, index) => {
        const descriptor = this.#normalize(item, index, atMaximum);
        if (descriptor.flags.group) {
          currentGroupOrdinal = nextGroupOrdinal++;
          // A structural row carries no ARIA position and does not advance the option count.
          return {
            ...descriptor,
            logicalIndex: undefined,
            groupOrdinal: currentGroupOrdinal,
            setSize: undefined,
            posInSet: undefined,
          };
        }
        if (descriptor.flags.divider) {
          currentGroupOrdinal = undefined;
          // A structural row carries no ARIA position and does not advance the option count.
          return {
            ...descriptor,
            logicalIndex: undefined,
            groupOrdinal: undefined,
            setSize: undefined,
            posInSet: undefined,
          };
        }
        const ordinal = optionOrdinal++;
        return {
          ...descriptor,
          logicalIndex: descriptor.flags.disabled ? undefined : logicalIndex++,
          groupOrdinal: descriptor.flags.__create
            ? undefined
            : currentGroupOrdinal,
          setSize,
          // The create row is appended after the source rows, so it closes the set wherever the
          // window ends.
          posInSet: ordinal < lastOptionOrdinal ? ordinal + 1 : setSize,
        };
      })
    );
  }

  #shouldOfferCreate(items: SelectItem[]): boolean {
    const filter = this.#getFilter();
    if (!filter || !this.#options.createItem) {
      return false;
    }
    const allowed =
      typeof this.#options.allowCreate === "function"
        ? this.#options.allowCreate(filter, items)
        : !!this.#options.allowCreate;
    if (!allowed) {
      return false;
    }
    // Don't offer to create a value that already exists (by label or value).
    const term = filter.toLowerCase();
    return !items.some(
      (item) =>
        String(this.#options.itemLabel(item) ?? "").toLowerCase() === term ||
        String(this.#options.itemValue(item) ?? "").toLowerCase() === term
    );
  }

  #normalize(
    item: SelectItem,
    index: number,
    atMaximum: boolean
  ): SelectDescriptor {
    const value = this.#options.itemValue(item);
    // An action row runs a callback and never becomes a value, so it cannot be the selection even
    // when its id collides with a held one — `isSelected` compares values and cannot tell the two
    // apart. The public `isSelected` is deliberately left alone: it answers a question about
    // values, and `activate` short-circuits on `onSelect` before any path that consults it.
    const selected =
      this.#isSelected(item) && typeof item.onSelect !== "function";
    return {
      // A value-less synthetic row (e.g. a null-id special) has no natural key; fall back to
      // its position, which is stable within the ordered special/create prefix.
      key: this.#options.valueKey(value) ?? `__row:${index}`,
      value,
      item,
      flags: {
        selected,
        // At the cap only rows that could actually grow the selection are closed off. A
        // selected row stays open (deselecting it is how the user gets back under the cap), and
        // so do action rows and structural rows, neither of which ever becomes a value.
        disabled:
          !!item.disabled ||
          (atMaximum &&
            !selected &&
            !this.#isStructural(item) &&
            typeof item.onSelect !== "function"),
        group: !!item.__header,
        divider: !!item.__divider,
        __create: !!item.__create,
        __unresolved: !!item.__unresolved,
        __none: !!item.__none,
      },
    };
  }

  #isStructural(item: SelectItem): boolean {
    return !!item.__header || !!item.__divider;
  }

  /**
   * The synthetic single-select "none" row: a selectable option carrying a `null` value. Shown only
   * while the filter is empty — a "none" row that survived filtering would sit at the top of a
   * non-matching result and, being auto-highlighted, turn "type a non-match, press Enter" into a
   * silent clear (and would suppress the empty state). Selecting it routes through the normal
   * `select()` path, which emits `null` because the row's value field is `null`.
   */
  #noneRow(): SelectItem | null {
    if (this.#options.noneLabel == null || this.#getFilter() !== "") {
      return null;
    }
    return {
      [this.#options.valueField]: null,
      [this.#options.labelField]: this.#options.noneLabel,
      __none: true,
    };
  }

  /**
   * Client sources only: a paginating source can split a group across pages, so grouping a
   * single page would fragment it. Deferred for server sources.
   */
  #shouldGroup(): boolean {
    return this.#options.groupBy != null && !this.#options.isAsync;
  }

  #groupKey(item: SelectItem): SelectItemId {
    return typeof this.#options.groupBy === "function"
      ? this.#options.groupBy(item)
      : item[this.#options.groupBy as string];
  }

  #groupLabel(key: SelectItemId): string | null | undefined {
    return this.#options.groupLabel?.(key);
  }

  /**
   * Labels turn group boundaries into headers; nullish labels use splitters, with a leading
   * splitter suppressed because it separates nothing.
   */
  #groupItems(options: SelectItem[]): SelectItem[] {
    const groups = new Map<SelectItemId, SelectItem[]>();
    for (const item of options) {
      // Grouping addresses options only. A structural row that reached the source (e.g. an
      // upstream transformer) is skipped rather than passed to `groupBy`, which would throw on
      // a synthetic row or spawn an option-less phantom group.
      if (this.#isStructural(item)) {
        continue;
      }
      const key = this.#groupKey(item);
      const bucket = groups.get(key);
      if (bucket) {
        bucket.push(item);
      } else {
        groups.set(key, [item]);
      }
    }

    const out: SelectItem[] = [];
    for (const [key, groupItems] of groups) {
      const label = this.#groupLabel(key);
      if (label != null) {
        out.push({ __header: true, groupKey: key, label });
      } else if (out.length > 0) {
        out.push({ __divider: true, groupKey: key });
      }
      out.push(...groupItems);
    }
    return out;
  }

  #snapshot(): SelectSnapshot {
    return Object.freeze({
      filter: this.#getFilter(),
      value: this.#getValue(),
      hasValue: this.#getHasValue(),
    });
  }
}
