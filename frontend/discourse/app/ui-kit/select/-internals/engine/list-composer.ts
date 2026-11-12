import { DEBUG } from "@glimmer/env";
import { assert, warn } from "@ember/debug";
import { makeArray } from "discourse/lib/helpers";
import type SelectArgsView from "discourse/ui-kit/select/-internals/engine/select-args";
import type {
  SelectId,
  SelectRecord,
  SelectRow,
  SelectSnapshot,
  SelectValue,
} from "discourse/ui-kit/select/select-engine";
import type { SelectContentContext } from "./customizations.ts";
import { optionsFromLegacyRows } from "./legacy-rows.ts";
import { engineKey, groupIdentity, recordKey } from "./row-keys.ts";
import {
  engineOption,
  optionKind,
  type SelectOption,
  selectOption,
  type SelectOptionLike,
} from "./select-option.ts";

/** One group of options: a merged key for a client source, a consecutive run for a paged one. */
interface GroupRun {
  key: SelectId;
  identity: string;
  /** How many earlier runs share this key; 0 for the first and for every client group. */
  occurrence: number;
  options: SelectOption[];
}

/** What every row of one emitted group carries into its row. */
interface GroupStamp {
  ordinal: number;
  text: { header: boolean; footer: boolean };
}

/** A group's header or footer, and the group it belongs to. */
interface Boundary {
  side: "header" | "footer";
  group: GroupRun;
  action: boolean;
}

/** One line of the list before it is described: an option and where grouping placed it. */
interface PlacedRow {
  option: SelectOption;
  stamp?: GroupStamp;
  boundary?: Boundary;
  /** The group a splitter leads. */
  splitter?: GroupRun;
}

/** Grouped rows, and the number of action boundaries among them. */
interface GroupedRows {
  rows: PlacedRow[];
  actions: number;
}

type BoundaryKind = "none" | "text" | "action";

export default class ListComposer {
  #args: SelectArgsView;
  #getFilter: () => string;
  #getValue: () => SelectValue;
  #getHasValue: () => boolean;
  #isSelected: (entry: SelectOptionLike) => boolean;
  #isLockedValue: (value: SelectId) => boolean;
  #getAtMaximum: () => boolean;
  #getTotal: () => number | undefined;
  #getContentContext: () => Omit<SelectContentContext, "filter" | "value">;

  /** Native content steps run before the compatibility bridge. */
  #applyContent: (
    records: SelectRecord[],
    context: SelectContentContext
  ) => SelectOptionLike[];
  #applyLegacyContent: (records: SelectRecord[]) => SelectRecord[];

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

  /** The none option, kept while its label stays the same so its row never re-renders. */
  #none?: { label: string; option: SelectOption };

  constructor(opts: {
    args: SelectArgsView;
    getFilter: () => string;
    getValue: () => SelectValue;
    getHasValue: () => boolean;
    isSelected: (entry: SelectOptionLike) => boolean;
    isLockedValue: (value: SelectId) => boolean;
    getAtMaximum: () => boolean;
    getTotal: () => number | undefined;
    getContentContext: () => Omit<SelectContentContext, "filter" | "value">;
    /** Applies sealed per-select content declarations. */
    applyContent: (
      records: SelectRecord[],
      context: SelectContentContext
    ) => SelectOptionLike[];
    applyLegacyContent: (records: SelectRecord[]) => SelectRecord[];
    /** Records the options left after content extensions, with the raw row count they came from. */
    noteVisible: (visible: number, input: number) => void;
    /** Whether the source may still add rows to this query, a page in flight or not. */
    canGrow: () => boolean;
  }) {
    this.#args = opts.args;
    this.#getFilter = opts.getFilter;
    this.#getValue = opts.getValue;
    this.#getHasValue = opts.getHasValue;
    this.#isSelected = opts.isSelected;
    this.#getAtMaximum = opts.getAtMaximum;
    this.#isLockedValue = opts.isLockedValue;
    this.#getTotal = opts.getTotal;
    this.#getContentContext = opts.getContentContext;
    this.#applyContent = opts.applyContent;
    this.#applyLegacyContent = opts.applyLegacyContent;
    this.#noteVisible = opts.noteVisible;
    this.#canGrow = opts.canGrow;
  }

  /**
   * Builds the rendered rows from the source's options: applies content customizations,
   * groups the options, and adds the extra and create options.
   *
   * @param sourceOptions - The options the source resolved.
   * @param filter - The query that produced them, retained for create checks during a reload.
   * @returns The frozen rows to render.
   */
  buildRows(
    sourceOptions: SelectOption[] = [],
    filter = this.#getFilter()
  ): readonly SelectRow[] {
    const loaded = makeArray(sourceOptions) as SelectOption[];
    // The source validates a measurement against the options it holds.
    const rawCount = loaded.length;

    let options = this.#throughRecords(loaded, (records) =>
      this.#applyContent(records, {
        filter: this.#getFilter(),
        value: this.#getValue(),
        ...this.#getContentContext(),
      })
    );

    // Legacy `modifySelectKit(id).{prepend,append,replace}Content` extensions run in
    // their own stage, after native customizations, so ordering is deterministic and
    // does not depend on global registration order.
    options = this.#throughRecords(options, (records) =>
      this.#applyLegacyContent(records)
    );
    this.#noteVisible(options.length, rawCount);

    // Runs are found before held options are hidden, so what is selected never renumbers them.
    const runs =
      this.#shouldGroup() && this.#args.isAsync
        ? this.#assignRuns(options)
        : undefined;
    // The next page may continue the last run, so its footer waits rather than move later.
    const held =
      runs && this.#canGrow() ? this.#trailingRun(loaded, runs) : undefined;
    const extending = runs ? this.#trackExtension(filter, rawCount) : false;

    const createCandidate = this.#createOption(options, filter);
    const hideSelected = this.#args.hideSelected;
    const include = (option: SelectOption) =>
      !hideSelected ||
      option.action ||
      this.#isStructural(option) ||
      !this.#isSelected(option);
    const create =
      createCandidate && include(createCandidate) ? createCandidate : null;
    options = options.filter(include);

    const allExtra = this.#extraOptions(options);
    // One option per value: an extra option comes first, so it keeps its value.
    const extraKeys = new Set(
      allExtra.map((option) => this.#keyOf(option)).filter((key) => key != null)
    );
    if (extraKeys.size) {
      options = options.filter((option) => {
        const key = this.#keyOf(option);
        return key == null || !extraKeys.has(key);
      });
    }
    const extra = allExtra.filter(include);
    // Sticky options lead the whole list, ahead of the none option, so they are hoisted out of
    // both the extras and the source options before grouping, which never reaches them.
    const isSticky = (option: SelectOption) => option.position === "sticky";
    const sticky = [...extra, ...options].filter(isSticky);
    options = options.filter((option) => !isSticky(option));
    const sourceCount = options.length;

    // Only source options are grouped; the create option belongs to no group.
    const grouped: GroupedRows = this.#shouldGroup()
      ? this.#groupOptions(options, runs, held, extending)
      : { rows: options.map((option) => ({ option })), actions: 0 };

    const none = this.#noneOption();
    const scrollingExtra = extra.filter((option) => !isSticky(option));
    // The none option leads the scrolling extras and flows through the same counting path
    // below, keeping its `posInSet`/`setSize`/`logicalIndex` in lockstep with the rest.
    const leading = none
      ? [...sticky, none, ...scrollingExtra]
      : [...sticky, ...scrollingExtra];
    const rows: PlacedRow[] = [
      ...leading.map((option) => ({ option })),
      ...(create ? [{ option: create }] : []),
      ...grouped.rows,
    ];

    return this.#describeList(
      rows,
      leading.length,
      sourceCount,
      rawCount,
      create,
      grouped
    );
  }

  /**
   * Rows for held records, as the trigger and chips draw them.
   *
   * @param records - The held records.
   * @param isUnresolved - Whether a record is the engine's fallback for an unresolved value.
   */
  describeRecords(
    records: SelectRecord[],
    isUnresolved: (record: SelectRecord) => boolean
  ): readonly SelectRow[] {
    return Object.freeze(
      // Never cap-disabled: these describe the held selection for the trigger, and the cap only
      // ever closes off options that are *not* selected.
      records.map((record, index) => {
        const row = this.#describe(
          { option: selectOption(record) },
          index,
          false
        );
        row.flags.unresolved = isUnresolved(record);
        return row;
      })
    );
  }

  /** Runs a record-level step and maps what it returned back to options. */
  #throughRecords(
    options: SelectOption[],
    step: (records: SelectRecord[]) => readonly SelectOptionLike[]
  ): SelectOption[] {
    const records = options.map((option) => option.record);
    const result = step(records);
    if (
      result.length === records.length &&
      result.every((record, index) => record === records[index])
    ) {
      return options;
    }
    return optionsFromLegacyRows(options, result, this.#args);
  }

  /** The value key an option is listed under, or `null` for a value-less option. */
  #keyOf(option: SelectOption): string | null {
    return this.#args.valueKey(this.#args.recordValue(option.record));
  }

  /** The extra options the select adds beside its source, wrapped, one per value. */
  #extraOptions(sourceOptions: readonly SelectOption[]): SelectOption[] {
    const entries = makeArray(
      this.#args.extraOptions?.(this.#snapshot(), this.#args.config) ?? []
    ) as SelectOptionLike[];
    const keys = new Set<string>();
    const extra = entries
      .map((entry) => this.#args.wrapEntry(entry))
      .filter((option) => {
        const key = this.#keyOf(option);
        if (key == null) {
          return true;
        }
        if (keys.has(key)) {
          return false;
        }
        keys.add(key);
        return true;
      });
    if (DEBUG) {
      const records = new Set<object>(sourceOptions.map((o) => o.record));
      for (const option of extra) {
        assert(
          "DSelect: the same record is listed twice, as an extra option and in the list. " +
            "Give one record one option.",
          !records.has(option.record)
        );
        records.add(option.record);
      }
    }
    return extra;
  }

  /**
   * Describes the leading options, create, then grouped source rows, and stamps each OPTION with
   * its position in the whole result set. Positions come from the engine's own totals rather
   * than the DOM index, so they stay correct while only a window is mounted, and they count
   * options only: an interleaved header or divider shifts no option's `posInSet` and never enters
   * `setSize`. A group's action header or footer is an option, so it is numbered and counted,
   * but never by paging.
   */
  #describeList(
    rows: PlacedRow[],
    leadingCount: number,
    sourceCount: number,
    inputCount: number,
    create: SelectOption | null,
    grouped: GroupedRows
  ): readonly SelectRow[] {
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
      !this.#args.isAsync || total == null
        ? sourceCount
        : Math.max(total + sourceCount - inputCount, sourceCount);
    const setSize =
      leadingCount + sourceTotal + (create ? 1 : 0) + grouped.actions;

    // Hoisted: the cap is a property of the selection, not of a row, and `#atMaximum` reads the
    // deduped value array — so evaluating it per row would repeat that work for every option.
    const atMaximum = this.#getAtMaximum();

    let optionOrdinal = 0;
    let logicalIndex = 0;
    return Object.freeze(
      rows.map((placed, index) => {
        const row = this.#describe(placed, index, atMaximum);
        const group = {
          groupOrdinal: placed.stamp?.ordinal,
          groupText: placed.stamp?.text,
        };
        if (row.flags.textBoundary || row.flags.divider) {
          // A structural row carries no ARIA position and does not advance the option count.
          return {
            ...row,
            ...group,
            logicalIndex: undefined,
            setSize: undefined,
            posInSet: undefined,
          };
        }
        const ordinal = optionOrdinal++;
        return {
          ...row,
          ...group,
          logicalIndex: logicalIndex++,
          setSize,
          posInSet: ordinal + 1,
        };
      })
    );
  }

  #createOption(options: SelectOption[], filter: string): SelectOption | null {
    if (!filter || !this.#args.createOption) {
      return null;
    }
    const records = options.map((option) => option.record);
    const allowed =
      typeof this.#args.allowCreate === "function"
        ? this.#args.allowCreate(filter, records, this.#args.config)
        : !!this.#args.allowCreate;
    if (!allowed) {
      return null;
    }
    const term = filter.toLowerCase();
    if (
      records.some(
        (record) =>
          String(this.#args.recordLabel(record) ?? "").toLowerCase() === term
      )
    ) {
      return null;
    }
    const built = this.#args.wrapEntry(
      this.#args.createOption(filter, this.#args.config)
    );
    const key = this.#args.valueKey(this.#args.recordValue(built.record));
    if (
      records.some(
        (record) => this.#args.valueKey(this.#args.recordValue(record)) === key
      )
    ) {
      return null;
    }
    return engineOption("create", built.record, built.settings);
  }

  #describe(placed: PlacedRow, index: number, atMaximum: boolean): SelectRow {
    const { option, boundary } = placed;
    const kind = optionKind(option);
    const value = this.#args.recordValue(option.record);
    const structural = this.#isStructural(option);
    // An action option runs a callback and never becomes a value, so it cannot be the
    // selection even when its id collides with a held one — `isSelected` compares values and
    // cannot tell the two apart.
    const selected = !structural && !option.action && this.#isSelected(option);
    const reasonDisabled = option.disabled;
    const locked = selected && this.#isLockedValue(value);
    const capDisabled =
      atMaximum && !selected && !structural && (!option.action || !!boundary);
    return {
      key: this.#rowKey(placed, value, index),
      value,
      record: option.record,
      option,
      group: boundary
        ? Object.freeze({ key: boundary.group.key, action: boundary.action })
        : undefined,
      flags: {
        selected,
        sticky: option.position === "sticky" && !structural && !boundary,
        // At the cap only rows that could actually grow the selection are closed off. A
        // selected option stays open (deselecting it is how the user gets back under the cap),
        // and so do action options and structural rows, neither of which ever becomes a value.
        // A group's action header or footer is the exception: it acts by adding the group.
        disabled: reasonDisabled || capDisabled || locked,
        reasonDisabled,
        capDisabled,
        locked,
        groupHeader: boundary?.side === "header",
        groupFooter: boundary?.side === "footer",
        textBoundary: kind === "text-header" || kind === "text-footer",
        divider: kind === "divider",
        action: option.action,
        create: option.create,
        unresolved: false,
        none: option.none,
      },
    };
  }

  /**
   * Group rows and the none option take engine keys that follow what they stand for, not where
   * they sit, so they keep their DOM rows when earlier rows come and go.
   */
  #rowKey(placed: PlacedRow, value: SelectId, index: number): string {
    const group = placed.boundary?.group ?? placed.splitter;
    if (group) {
      const tag = placed.splitter
        ? "d"
        : placed.boundary!.side === "header"
          ? "h"
          : "f";
      // The run count sits in the tag, before the separator, so no group key can mimic it.
      return engineKey(
        `${tag}${group.occurrence || ""}:${groupIdentity(group.key)}`
      );
    }
    if (placed.option.none) {
      return engineKey("none");
    }
    const key = this.#args.valueKey(value);
    // A value-less row (a null-id extra option) has no natural key; its position is stable
    // within the ordered leading options.
    return key == null ? engineKey(`row:${index}`) : recordKey(key);
  }

  #isStructural(option: SelectOption): boolean {
    const kind = optionKind(option);
    return (
      kind === "text-header" || kind === "text-footer" || kind === "divider"
    );
  }

  /**
   * The single-select none option: a selectable option whose value is `null`. Shown only while
   * the filter is empty — a none option that survived filtering would sit at the top of a
   * non-matching result and, being auto-highlighted, turn "type a non-match, press Enter" into a
   * silent clear (and would suppress the empty state). Selecting it routes through the normal
   * `select()` path, which emits `null` because its record's value field is `null`.
   */
  #noneOption(): SelectOption | null {
    const label = this.#args.noneLabel;
    if (label == null || this.#getFilter() !== "") {
      return null;
    }
    if (this.#none?.label !== label) {
      this.#none = {
        label,
        option: engineOption(
          "none",
          Object.freeze({
            [this.#args.valueField]: null,
            [this.#args.labelField]: label,
          })
        ),
      };
    }
    return this.#none.option;
  }

  #shouldGroup(): boolean {
    return this.#args.groupBy != null;
  }

  #groupKey(option: SelectOption): SelectId {
    return typeof this.#args.groupBy === "function"
      ? this.#args.groupBy(option.record, this.#args.config)
      : option.record[this.#args.groupBy as string];
  }

  /**
   * Builds one boundary. Text becomes a presentational row and an action option is placed as it
   * is; anything else is a mistake, dropped after the development assertion.
   */
  #boundary(
    side: "header" | "footer",
    group: GroupRun,
    options: readonly SelectOption[]
  ): PlacedRow | null {
    const build =
      side === "header" ? this.#args.groupHeader : this.#args.groupFooter;
    const result = build?.(group.key, options, this.#args.config);
    if (result == null) {
      return null;
    }
    if (typeof result === "string") {
      return {
        option: engineOption(
          side === "header" ? "text-header" : "text-footer",
          Object.freeze({ label: result })
        ),
        boundary: { side, group, action: false },
      };
    }
    const option =
      typeof result === "object" ? this.#args.wrapEntry(result) : undefined;
    if (option?.action) {
      return { option, boundary: { side, group, action: true } };
    }
    assert(
      `DSelect: \`@group${side === "header" ? "Header" : "Footer"}\` must return text, an action option, or nothing`,
      false
    );
    return null;
  }

  /** The run of the last loaded option grouping placed; options injected after it never count. */
  #trailingRun(
    loaded: SelectOption[],
    runs: Map<SelectRecord, GroupRun>
  ): GroupRun | undefined {
    for (let index = loaded.length - 1; index >= 0; index--) {
      const run = runs.get(loaded[index].record);
      if (run) {
        return run;
      }
    }
    // A customization that copies records leaves none to find; holding the last run keeps it
    // safe.
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
    header: PlacedRow | null,
    footer: PlacedRow | null | undefined,
    extending: boolean
  ): void {
    const kindOf = (row: PlacedRow | null): BoundaryKind => {
      if (!row) {
        return "none";
      }
      return row.boundary?.action ? "action" : "text";
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
   * A paged source groups consecutive options, so a later page only ever appends: it extends
   * the last run or starts new ones. A key that comes back later starts another run. Runs are
   * keyed by record, so a step that gives an option new settings never moves it to a new run.
   */
  #assignRuns(options: SelectOption[]): Map<SelectRecord, GroupRun> {
    const runs = new Map<SelectRecord, GroupRun>();
    const occurrences = new Map<string, number>();
    let current: GroupRun | undefined;
    for (const option of options) {
      if (option.position === "sticky") {
        continue;
      }
      const key = this.#groupKey(option);
      const identity = groupIdentity(key);
      if (current?.identity !== identity) {
        const occurrence = occurrences.get(identity) ?? 0;
        occurrences.set(identity, occurrence + 1);
        current = { key, identity, occurrence, options: [] };
      }
      runs.set(option.record, current);
    }
    return runs;
  }

  /**
   * Wraps each group in its boundaries: a header or, failing one, a splitter (never at the head
   * of the list) before its options, and a footer after them unless the group is `held`.
   * Without `runs`, a client source merges every option of a key into one group, in
   * first-appearance order.
   */
  #groupOptions(
    options: SelectOption[],
    runs: Map<SelectRecord, GroupRun> | undefined,
    held: GroupRun | undefined,
    extending: boolean
  ): GroupedRows {
    const groups = new Map<string | GroupRun, GroupRun>();
    for (const option of options) {
      const run = runs?.get(option.record);
      if (run) {
        if (!groups.has(run)) {
          groups.set(run, { ...run, options: [] });
        }
        groups.get(run)!.options.push(option);
        continue;
      }
      const key = this.#groupKey(option);
      const identity = groupIdentity(key);
      const bucket = groups.get(identity);
      if (bucket) {
        bucket.options.push(option);
      } else {
        groups.set(identity, {
          key,
          identity,
          occurrence: 0,
          options: [option],
        });
      }
    }

    const out: PlacedRow[] = [];
    let ordinal = 0;
    let actions = 0;
    for (const [source, group] of groups) {
      const members = Object.freeze([...group.options]);
      const header = this.#boundary("header", group, members);
      const footer =
        source === held ? undefined : this.#boundary("footer", group, members);
      if (runs) {
        this.#noteBoundaries(group, header, footer, extending);
      }

      const stamp: GroupStamp = {
        ordinal: ordinal++,
        text: {
          header: !!header && !header.boundary!.action,
          footer: !!footer && !footer.boundary!.action,
        },
      };
      if (!header && out.length > 0 && this.#args.groupDividers) {
        out.push({
          option: engineOption("divider", Object.freeze({})),
          splitter: group,
        });
      }
      const placed: PlacedRow[] = [
        ...(header ? [header] : []),
        ...members.map((option) => ({ option })),
        ...(footer ? [footer] : []),
      ];
      for (const row of placed) {
        out.push({ ...row, stamp });
      }
      actions += [header, footer].filter((row) => row?.boundary?.action).length;
    }
    return { rows: out, actions };
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
