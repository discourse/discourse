import { makeArray } from "discourse/lib/helpers";
import type SelectOptionsView from "discourse/ui-kit/select/-internals/engine/select-options";
import type {
  SelectDescriptor,
  SelectItem,
  SelectItemId,
  SelectSnapshot,
  SelectValue,
} from "discourse/ui-kit/select/select-engine";
import type { SelectContentContext } from "./customizations.ts";

export default class ListComposer {
  #options: SelectOptionsView;
  #getFilter: () => string;
  #getValue: () => SelectValue;
  #getHasValue: () => boolean;
  #isSelected: (item: SelectItem) => boolean;
  #getAtMaximum: () => boolean;
  #getTotal: () => number | undefined;
  #getContentContext: () => Omit<SelectContentContext, "filter" | "value">;

  /** Native content steps run before the compatibility bridge. */
  #applyContent: (
    items: SelectItem[],
    context: SelectContentContext
  ) => SelectItem[];
  #applyLegacyContent: (items: SelectItem[]) => SelectItem[];

  /** Records transformed option counts without invalidating the current render. */
  #noteVisible: (visible: number, input: number) => void;

  constructor(opts: {
    options: SelectOptionsView;
    getFilter: () => string;
    getValue: () => SelectValue;
    getHasValue: () => boolean;
    isSelected: (item: SelectItem) => boolean;
    getAtMaximum: () => boolean;
    getTotal: () => number | undefined;
    getContentContext: () => Omit<SelectContentContext, "filter" | "value">;
    /** Applies sealed per-select content declarations. */
    applyContent: (
      items: SelectItem[],
      context: SelectContentContext
    ) => SelectItem[];
    applyLegacyContent: (items: SelectItem[]) => SelectItem[];
    /** Measures source options before and after content extensions. */
    noteVisible: (visible: number, input: number) => void;
  }) {
    this.#options = opts.options;
    this.#getFilter = opts.getFilter;
    this.#getValue = opts.getValue;
    this.#getHasValue = opts.getHasValue;
    this.#isSelected = opts.isSelected;
    this.#getAtMaximum = opts.getAtMaximum;
    this.#getTotal = opts.getTotal;
    this.#getContentContext = opts.getContentContext;
    this.#applyContent = opts.applyContent;
    this.#applyLegacyContent = opts.applyLegacyContent;
    this.#noteVisible = opts.noteVisible;
  }

  /**
   * Builds the final rendered item list from the source's resolved items: applies
   * content customizations, groups the options, and prepends special and create items.
   *
   * @param rawItems - The items resolved by the source.
   * @param filter - The query that produced these rows, retained for create checks during a reload.
   * @returns The frozen list of normalized descriptors to render.
   */
  buildItems(
    rawItems: SelectItem[] = [],
    filter = this.#getFilter()
  ): readonly SelectDescriptor[] {
    let items: SelectItem[] = [...(makeArray(rawItems) as SelectItem[])];
    const inputCount = items.filter((item) => !this.#isStructural(item)).length;

    items = this.#applyContent(items, {
      filter: this.#getFilter(),
      value: this.#getValue(),
      ...this.#getContentContext(),
    });

    // Legacy `modifySelectKit(id).{prepend,append,replace}Content` extensions run in
    // their own stage, after native customizations, so ordering is deterministic and
    // does not depend on global registration order.
    items = this.#applyLegacyContent(items);

    // The option count never includes structural rows (headers/dividers), whether they come
    // from grouping below or an upstream injector.
    const visibleCount = items.filter(
      (item) => !this.#isStructural(item)
    ).length;
    this.#noteVisible(visibleCount, inputCount);

    const createCandidate = this.#createItem(items, filter);
    const hideSelected = this.#options.hideSelected;
    const include = (item: SelectItem) =>
      !hideSelected ||
      this.#isStructural(item) ||
      typeof item.onSelect === "function" ||
      !this.#isSelected(item);
    const createItem =
      createCandidate && include(createCandidate) ? createCandidate : null;
    items = items.filter(include);

    const consumerSpecial = makeArray(
      this.#options.specialItems?.(
        this.#snapshot(),
        this.#options.resolvedOptions
      ) ?? []
    ) as SelectItem[];
    const visibleSpecial = consumerSpecial.filter(include);
    // Sticky rows lead the whole list, ahead of the none row, so they are hoisted out of both the
    // specials and the source rows before grouping, which never reaches them.
    const isSticky = (item: SelectItem) =>
      !!item.sticky && !this.#isStructural(item);
    const sticky = [...visibleSpecial, ...items].filter(isSticky);
    items = items.filter((item) => !isSticky(item));
    const sourceCount = items.filter(
      (item) => !this.#isStructural(item)
    ).length;

    // Only source options are grouped; the create row belongs to no group.
    const grouped = this.#shouldGroup() ? this.#groupItems(items) : items;

    const noneRow = this.#noneRow();
    const scrollingSpecial = visibleSpecial.filter((item) => !isSticky(item));
    // The none row leads the scrolling specials and flows through the same counting path below,
    // keeping its `posInSet`/`setSize`/`logicalIndex` in lockstep with the rest of the set.
    const specialItems = noneRow
      ? [...sticky, noneRow, ...scrollingSpecial]
      : [...sticky, ...scrollingSpecial];
    const finalItems = createItem
      ? [...specialItems, createItem, ...grouped]
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
      inputCount,
      createItem
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
   * Normalizes specials, create, then grouped source rows, and stamps each OPTION with its
   * position in the whole result set. Positions come from the engine's own totals rather
   * than the DOM index, so they stay correct while
   * only a window is mounted, and they count options only: an interleaved header/divider
   * shifts no option's `posInSet` and never enters `setSize`.
   */
  #describeList(
    items: SelectItem[],
    specialCount: number,
    sourceCount: number,
    inputCount: number,
    createItem: SelectItem | null
  ): readonly SelectDescriptor[] {
    const total = this.#getTotal();
    // `aria-setsize` describes the complete set rather than the rendered rows, so a source that
    // declares its total has already answered; withholding it until the last page lands would
    // report "unknown" about something known. Transformers change what the reader can reach, so
    // their net change adjusts that total, floored at the rows shown.
    //
    // A source that declares no total is sized by what it has loaded, never by `-1`. That sentinel
    // is unusable in practice: no two engines interpret it alike, and its own AAM tells user agents
    // to substitute 1. The loaded rows are the ones the reader can reach anyway, and "there is
    // more" is carried by the announcements that can express it.
    //
    // A client source is always sized by the rows shown: under a debounce its total already
    // counts the next filter while the previous rows are still on screen.
    const sourceTotal =
      !this.#options.isAsync || total == null
        ? sourceCount
        : Math.max(total + sourceCount - inputCount, sourceCount);
    const setSize = specialCount + sourceTotal + (createItem ? 1 : 0);

    // Hoisted: the cap is a property of the selection, not of a row, and `#atMaximum` reads the
    // deduped value array — so evaluating it per row would repeat that work for every option.
    const atMaximum = this.#getAtMaximum();

    let optionOrdinal = 0;
    let logicalIndex = 0;
    let nextGroupOrdinal = 0;
    let currentGroupOrdinal: number | undefined;
    return Object.freeze(
      items.map((item, index) => {
        const descriptor = this.#normalize(
          item,
          index,
          atMaximum,
          item === createItem
        );
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
          logicalIndex: logicalIndex++,
          groupOrdinal: descriptor.flags.__create
            ? undefined
            : currentGroupOrdinal,
          setSize,
          posInSet: ordinal + 1,
        };
      })
    );
  }

  #createItem(items: SelectItem[], filter: string): SelectItem | null {
    if (!filter || !this.#options.createItem) {
      return null;
    }
    const allowed =
      typeof this.#options.allowCreate === "function"
        ? this.#options.allowCreate(
            filter,
            items,
            this.#options.resolvedOptions
          )
        : !!this.#options.allowCreate;
    if (!allowed) {
      return null;
    }
    const term = filter.toLowerCase();
    if (
      items.some(
        (item) =>
          String(this.#options.itemLabel(item) ?? "").toLowerCase() === term
      )
    ) {
      return null;
    }
    const item = this.#options.createItem(
      filter,
      this.#options.resolvedOptions
    );
    const key = this.#options.valueKey(this.#options.itemValue(item));
    return items.some(
      (loaded) =>
        this.#options.valueKey(this.#options.itemValue(loaded)) === key
    )
      ? null
      : item;
  }

  #normalize(
    item: SelectItem,
    index: number,
    atMaximum: boolean,
    isCreate = false
  ): SelectDescriptor {
    const value = this.#options.itemValue(item);
    // An action row runs a callback and never becomes a value, so it cannot be the selection even
    // when its id collides with a held one — `isSelected` compares values and cannot tell the two
    // apart. The public `isSelected` is deliberately left alone: it answers a question about
    // values, and `activate` short-circuits on `onSelect` before any path that consults it.
    const selected =
      this.#isSelected(item) && typeof item.onSelect !== "function";
    const reasonDisabled = !!item.disabled;
    const capDisabled =
      atMaximum &&
      !selected &&
      !this.#isStructural(item) &&
      typeof item.onSelect !== "function";
    return {
      // A value-less synthetic row (e.g. a null-id special) has no natural key; fall back to
      // its position, which is stable within the ordered special/create prefix.
      key: this.#options.valueKey(value) ?? `__row:${index}`,
      value,
      item,
      flags: {
        selected,
        sticky: !!item.sticky && !this.#isStructural(item),
        // At the cap only rows that could actually grow the selection are closed off. A
        // selected row stays open (deselecting it is how the user gets back under the cap), and
        // so do action rows and structural rows, neither of which ever becomes a value.
        disabled: reasonDisabled || capDisabled,
        reasonDisabled,
        capDisabled,
        group: !!item.__header,
        divider: !!item.__divider,
        __create: isCreate || !!item.__create,
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
      ? this.#options.groupBy(item, this.#options.resolvedOptions)
      : item[this.#options.groupBy as string];
  }

  #groupLabel(key: SelectItemId): string | null | undefined {
    return this.#options.groupLabel?.(key, this.#options.resolvedOptions);
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
