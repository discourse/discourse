import { DEBUG } from "@glimmer/env";
import { assert, warn } from "@ember/debug";
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
import { engineKey, groupIdentity, recordKey } from "./row-keys.ts";

/** One group of rows: a merged key for a client source, a consecutive run for a paged one. */
interface GroupRun {
  key: SelectItemId;
  identity: string;
  /** How many earlier runs share this key; 0 for the first and for every client group. */
  occurrence: number;
  items: SelectItem[];
}

/** What every row of one emitted group carries into its descriptor. */
interface GroupStamp {
  ordinal: number;
  text: { header: boolean; footer: boolean };
}

/** Grouped rows, with each row's group and the number of action boundaries among them. */
interface GroupedRows {
  rows: SelectItem[];
  stamps: Map<SelectItem, GroupStamp>;
  actions: number;
}

type BoundaryKind = "none" | "text" | "action";

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
  #canGrow: () => boolean;

  /** Each run's boundary kinds at the last build, to warn when a page changes one. */
  #boundaryKinds = new Map<
    string,
    { header: BoundaryKind; footer?: BoundaryKind }
  >();
  #boundaryQuery?: string;
  #boundaryRows = 0;

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
    /** Records the options left after content extensions, with the raw row count they came from. */
    noteVisible: (visible: number, input: number) => void;
    /** Whether the source may still add rows to this query, a page in flight or not. */
    canGrow: () => boolean;
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
    this.#canGrow = opts.canGrow;
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
    const loaded = makeArray(rawItems) as SelectItem[];
    let items: SelectItem[] = [...loaded];
    // The source validates a measurement against the rows it holds, structural ones included.
    const rawCount = items.length;
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
    this.#noteVisible(visibleCount, rawCount);

    // Runs are found before held rows are hidden, so what is selected never renumbers them.
    const runs =
      this.#shouldGroup() && this.#options.isAsync
        ? this.#assignRuns(items)
        : undefined;
    // The next page may continue the last run, so its footer waits rather than move later.
    const held =
      runs && this.#canGrow() ? this.#trailingRun(loaded, runs) : undefined;
    const extending = runs ? this.#trackExtension(filter, rawCount) : false;

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
    const grouped: GroupedRows = this.#shouldGroup()
      ? this.#groupItems(items, runs, held, extending)
      : { rows: items, stamps: new Map(), actions: 0 };

    const noneRow = this.#noneRow();
    const scrollingSpecial = visibleSpecial.filter((item) => !isSticky(item));
    // The none row leads the scrolling specials and flows through the same counting path below,
    // keeping its `posInSet`/`setSize`/`logicalIndex` in lockstep with the rest of the set.
    const specialItems = noneRow
      ? [...sticky, noneRow, ...scrollingSpecial]
      : [...sticky, ...scrollingSpecial];
    const finalItems = createItem
      ? [...specialItems, createItem, ...grouped.rows]
      : [...specialItems, ...grouped.rows];

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
      createItem,
      grouped
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
   * shifts no option's `posInSet` and never enters `setSize`. A group's action header or
   * footer is an option, so it is numbered and counted, but never by paging.
   */
  #describeList(
    items: SelectItem[],
    specialCount: number,
    sourceCount: number,
    inputCount: number,
    createItem: SelectItem | null,
    grouped: GroupedRows
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
    const setSize =
      specialCount + sourceTotal + (createItem ? 1 : 0) + grouped.actions;

    // Hoisted: the cap is a property of the selection, not of a row, and `#atMaximum` reads the
    // deduped value array — so evaluating it per row would repeat that work for every option.
    const atMaximum = this.#getAtMaximum();

    let optionOrdinal = 0;
    let logicalIndex = 0;
    return Object.freeze(
      items.map((item, index) => {
        const descriptor = this.#normalize(
          item,
          index,
          atMaximum,
          item === createItem
        );
        const stamp = grouped.stamps.get(item);
        const group = { groupOrdinal: stamp?.ordinal, groupText: stamp?.text };
        if (descriptor.flags.textBoundary || descriptor.flags.divider) {
          // A structural row carries no ARIA position and does not advance the option count.
          return {
            ...descriptor,
            ...group,
            logicalIndex: undefined,
            setSize: undefined,
            posInSet: undefined,
          };
        }
        const ordinal = optionOrdinal++;
        return {
          ...descriptor,
          ...group,
          logicalIndex: logicalIndex++,
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
    const groupAction = !!item.__groupHeader || !!item.__groupFooter;
    const capDisabled =
      atMaximum &&
      !selected &&
      !this.#isStructural(item) &&
      (typeof item.onSelect !== "function" || groupAction);
    return {
      key: this.#rowKey(item, value, index),
      value,
      item,
      flags: {
        selected,
        sticky: !!item.sticky && !this.#isStructural(item),
        // At the cap only rows that could actually grow the selection are closed off. A
        // selected row stays open (deselecting it is how the user gets back under the cap), and
        // so do action rows and structural rows, neither of which ever becomes a value. A
        // group's action header or footer is the exception: it acts by adding the group.
        disabled: reasonDisabled || capDisabled,
        reasonDisabled,
        capDisabled,
        groupHeader: !!item.__header || !!item.__groupHeader,
        groupFooter: !!item.__footer || !!item.__groupFooter,
        textBoundary: !!item.__header || !!item.__footer,
        divider: !!item.__divider,
        action: typeof item.onSelect === "function",
        __create: isCreate || !!item.__create,
        __unresolved: !!item.__unresolved,
        __none: !!item.__none,
      },
    };
  }

  /**
   * Group rows and the none row take engine keys that follow what they stand for, not where they
   * sit, so they keep their DOM rows when earlier rows come and go.
   */
  #rowKey(item: SelectItem, value: SelectItemId, index: number): string {
    const kind = this.#boundaryTag(item);
    if (kind && Object.hasOwn(item, "groupKey")) {
      // The run count sits in the tag, before the separator, so no group key can mimic it.
      const tag = `${kind}${item.groupRun || ""}`;
      return engineKey(`${tag}:${groupIdentity(item.groupKey)}`);
    }
    if (item.__none) {
      return engineKey("none");
    }
    const key = this.#options.valueKey(value);
    // A value-less row (a null-id special, or a structural row a loader returned) has no
    // natural key; its position is stable within the ordered special/create prefix.
    return key == null ? engineKey(`row:${index}`) : recordKey(key);
  }

  /** A header of either kind is `h`, so a group's rows never share a key whatever it returns. */
  #boundaryTag(item: SelectItem): string | null {
    if (item.__header || item.__groupHeader) {
      return "h";
    }
    if (item.__footer || item.__groupFooter) {
      return "f";
    }
    return item.__divider ? "d" : null;
  }

  #isStructural(item: SelectItem): boolean {
    return !!item.__header || !!item.__footer || !!item.__divider;
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

  #shouldGroup(): boolean {
    return this.#options.groupBy != null;
  }

  #groupKey(item: SelectItem): SelectItemId {
    return typeof this.#options.groupBy === "function"
      ? this.#options.groupBy(item, this.#options.resolvedOptions)
      : item[this.#options.groupBy as string];
  }

  /**
   * Builds one boundary. Text becomes a presentational row and an action row becomes a stamped
   * copy; anything else is a mistake, dropped after the development assertion.
   */
  #boundary(
    kind: "header" | "footer",
    group: GroupRun,
    rows: readonly SelectItem[]
  ): SelectItem | null {
    const build =
      kind === "header" ? this.#options.groupHeader : this.#options.groupFooter;
    const result = build?.(group.key, rows, this.#options.resolvedOptions);
    if (result == null) {
      return null;
    }
    const stamp = { groupKey: group.key, groupRun: group.occurrence };
    if (typeof result === "string") {
      const marker = kind === "header" ? "__header" : "__footer";
      return { [marker]: true, ...stamp, label: result };
    }
    if (typeof result === "object" && typeof result.onSelect === "function") {
      const marker = kind === "header" ? "__groupHeader" : "__groupFooter";
      const item: SelectItem = { ...result, [marker]: true, ...stamp };
      // A boundary belongs to its group, so it never leads the list.
      delete item.sticky;
      return item;
    }
    assert(
      `DSelect: \`@group${kind === "header" ? "Header" : "Footer"}\` must return text, an action row (an item with \`onSelect\`), or nothing`,
      false
    );
    return null;
  }

  /** The run of the last loaded row grouping placed; rows injected after it never count. */
  #trailingRun(
    loaded: SelectItem[],
    runs: Map<SelectItem, GroupRun>
  ): GroupRun | undefined {
    for (let index = loaded.length - 1; index >= 0; index--) {
      const run = runs.get(loaded[index]);
      if (run) {
        return run;
      }
    }
    // A customization that copies rows leaves none to find; holding the last run keeps it safe.
    return [...runs.values()].at(-1);
  }

  /**
   * Whether this build extends the last one's query with more rows, the only change across
   * which a boundary must keep its kind.
   */
  #trackExtension(filter: string, rowCount: number): boolean {
    if (!DEBUG) {
      return false;
    }
    const sameQuery = filter === this.#boundaryQuery;
    if (!sameQuery || rowCount < this.#boundaryRows) {
      this.#boundaryKinds.clear();
    }
    const extending = sameQuery && rowCount > this.#boundaryRows;
    this.#boundaryQuery = filter;
    this.#boundaryRows = rowCount;
    return extending;
  }

  /** Warns when a page changes a boundary's kind, which would shift rows already shown. */
  #noteBoundaries(
    group: GroupRun,
    header: SelectItem | null,
    footer: SelectItem | null | undefined,
    extending: boolean
  ): void {
    const kindOf = (row: SelectItem | null): BoundaryKind => {
      if (!row) {
        return "none";
      }
      return row.__header || row.__footer ? "text" : "action";
    };
    const id = `${group.occurrence}:${group.identity}`;
    const previous = this.#boundaryKinds.get(id);
    const next = {
      header: kindOf(header),
      // A held footer is unknown, not absent.
      footer: footer === undefined ? previous?.footer : kindOf(footer),
    };
    if (extending && previous) {
      this.#warnIfChanged("header", previous.header, next.header);
      this.#warnIfChanged("footer", previous.footer, next.footer);
    }
    this.#boundaryKinds.set(id, next);
  }

  /**
   * A paged source groups consecutive rows, so a later page only ever appends: it extends the
   * last run or starts new ones. A key that comes back later starts another run.
   */
  #assignRuns(items: SelectItem[]): Map<SelectItem, GroupRun> {
    const runs = new Map<SelectItem, GroupRun>();
    const occurrences = new Map<string, number>();
    let current: GroupRun | undefined;
    for (const item of items) {
      if (this.#isStructural(item) || item.sticky) {
        continue;
      }
      const key = this.#groupKey(item);
      const identity = groupIdentity(key);
      if (current?.identity !== identity) {
        const occurrence = occurrences.get(identity) ?? 0;
        occurrences.set(identity, occurrence + 1);
        current = { key, identity, occurrence, items: [] };
      }
      runs.set(item, current);
    }
    return runs;
  }

  /**
   * Wraps each group in its boundaries: a header or, failing one, a splitter (never at the head
   * of the list) before its rows, and a footer after them unless the group is `held`. Without
   * `runs`, a client source merges every row of a key into one group, in first-appearance order.
   */
  #groupItems(
    options: SelectItem[],
    runs: Map<SelectItem, GroupRun> | undefined,
    held: GroupRun | undefined,
    extending: boolean
  ): GroupedRows {
    const groups = new Map<string | GroupRun, GroupRun>();
    for (const item of options) {
      // Grouping addresses options only. A structural row that reached the source (e.g. an
      // upstream transformer) is skipped rather than passed to `groupBy`, which would throw on
      // a synthetic row or spawn an option-less phantom group.
      if (this.#isStructural(item)) {
        continue;
      }
      const run = runs?.get(item);
      if (run) {
        if (!groups.has(run)) {
          groups.set(run, { ...run, items: [] });
        }
        groups.get(run)!.items.push(item);
        continue;
      }
      const key = this.#groupKey(item);
      const identity = groupIdentity(key);
      const bucket = groups.get(identity);
      if (bucket) {
        bucket.items.push(item);
      } else {
        groups.set(identity, { key, identity, occurrence: 0, items: [item] });
      }
    }

    const out: SelectItem[] = [];
    const stamps = new Map<SelectItem, GroupStamp>();
    let ordinal = 0;
    let actions = 0;
    for (const [source, group] of groups) {
      const rows = Object.freeze([...group.items]);
      const header = this.#boundary("header", group, rows);
      const footer =
        source === held ? undefined : this.#boundary("footer", group, rows);
      if (runs) {
        this.#noteBoundaries(group, header, footer, extending);
      }

      const stamp: GroupStamp = {
        ordinal: ordinal++,
        text: { header: !!header?.__header, footer: !!footer?.__footer },
      };
      const members = [header, ...group.items, footer].filter(
        (row): row is SelectItem => !!row
      );
      if (!header && out.length > 0) {
        out.push({
          __divider: true,
          groupKey: group.key,
          groupRun: group.occurrence,
        });
      }
      for (const row of members) {
        out.push(row);
        stamps.set(row, stamp);
      }
      actions += [header, footer].filter(
        (row) => row && !this.#isStructural(row)
      ).length;
    }
    return { rows: out, stamps, actions };
  }

  #warnIfChanged(
    kind: "header" | "footer",
    before: BoundaryKind | undefined,
    after: BoundaryKind | undefined
  ): void {
    warn(
      `DSelect: the ${kind} of a group changed from ${before} to ${after} as more rows loaded. A group's header and footer must keep their kind (none, text or action) across pages; only their content may change.`,
      before === undefined || after === undefined || before === after,
      { id: "discourse.d-select.group-boundary-changed" }
    );
  }

  #snapshot(): SelectSnapshot {
    return Object.freeze({
      filter: this.#getFilter(),
      value: this.#getValue(),
      hasValue: this.#getHasValue(),
    });
  }
}
