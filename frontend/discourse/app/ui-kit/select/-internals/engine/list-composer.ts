import { DEBUG } from "@glimmer/env";
import { assert, warn } from "@ember/debug";
import { makeArray } from "discourse/lib/helpers";
import type SelectArgsView from "discourse/ui-kit/select/-internals/engine/select-args";
import type {
  SelectHeldRow,
  SelectId,
  SelectRecord,
  SelectRow,
  SelectSnapshot,
  SelectValue,
} from "discourse/ui-kit/select/select-engine";
import type { SelectContentContext } from "./customizations.ts";
import type { SelectResolvedOption } from "./resolved-option.ts";
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
  /** A rule an option asked for: its key follows the owner, and it pins with sticky options. */
  divider?: { key: string; sticky: boolean };
  /** Where the row sat before rules were drawn, so a rule coming or going never rekeys it. */
  at?: number;
}

/** Grouped rows, and the number of action boundaries among them. */
interface GroupedRows {
  rows: PlacedRow[];
  actions: number;
}

type BoundaryKind = "none" | "text" | "action";

/** Finds the list's resolved option for a key, given the option a row shows it through. */
type ResolvedLookup = (
  key: string,
  input: SelectOption
) => SelectResolvedOption | undefined;

/** An option paste can match, and the resolved option it is listed as. */
export interface PasteOption {
  option: SelectOption;
  resolved: SelectResolvedOption;
}

export default class ListComposer {
  #args: SelectArgsView;
  #getFilter: () => string;
  #getValue: () => SelectValue;
  #getHasValue: () => boolean;
  #isSelected: (entry: SelectOptionLike) => boolean;
  #isLockedValue: (value: SelectId) => boolean;
  #getAtMaximum: () => boolean;
  #getTotal: () => number | undefined;
  #viewRecord: (key: string, input: SelectOption) => SelectRecord | undefined;
  #resolvedOptionFor: ResolvedLookup;
  #peekOption: ResolvedLookup;
  #rowOption: (input: SelectOption) => SelectResolvedOption;
  #keepOptions: (keys: ReadonlySet<string>) => void;
  #getContentContext: () => Omit<SelectContentContext, "filter" | "value">;

  /** Native content steps run before the compatibility bridge. */
  #applyContent: (
    options: SelectOption[],
    context: SelectContentContext
  ) => SelectOption[];
  #applyLegacyContent: (options: SelectOption[]) => SelectOption[];

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
    /** The record a key stands for in the list, which a displayed copy never replaces. */
    viewRecord: (key: string, input: SelectOption) => SelectRecord | undefined;
    /** The list's resolved option for a row's key, given the row's own option. */
    resolvedOptionFor: ResolvedLookup;
    /** The same resolved option built afresh and never memoised, for matching outside a build. */
    peekOption: ResolvedLookup;
    /** The resolved option of a row that stands for no value key. */
    rowOption: (input: SelectOption) => SelectResolvedOption;
    /** Called after a build with the keys it showed, so other keys' resolved options can be let go. */
    keepOptions: (keys: ReadonlySet<string>) => void;
    getContentContext: () => Omit<SelectContentContext, "filter" | "value">;
    /** Applies sealed per-select content declarations. */
    applyContent: (
      options: SelectOption[],
      context: SelectContentContext
    ) => SelectOption[];
    /** Applies the compatibility bridge's legacy content callbacks. */
    applyLegacyContent: (options: SelectOption[]) => SelectOption[];
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
    this.#viewRecord = opts.viewRecord;
    this.#resolvedOptionFor = opts.resolvedOptionFor;
    this.#peekOption = opts.peekOption;
    this.#rowOption = opts.rowOption;
    this.#keepOptions = opts.keepOptions;
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

    let options = this.#content(loaded);
    this.#noteVisible(options.length, rawCount);

    // Every option now stands for its key's record, with its resolved option; what content changed on a
    // copy is kept as presentation.
    const byOption = new Map<SelectOption, SelectResolvedOption>();
    const originals = new Map<SelectOption, SelectOption>();
    const before = this.#byKey(loaded);
    const rawExtra = this.#wrapExtras(this.#snapshot());
    // A source option an extra replaces never reaches a row, so it never claims the key's resolved option.
    const resolvedOf = this.#unlessShadowed(rawExtra, this.#resolvedOptionFor);
    options = options.map((option) => {
      const normalized = this.#normalize(option, before, byOption, resolvedOf);
      originals.set(normalized, option);
      return normalized;
    });

    // Runs are found before held options are hidden, so what is selected never renumbers them.
    const runs =
      this.#shouldGroup() && this.#args.isAsync
        ? this.#assignRuns(options)
        : undefined;
    // The next page may continue the last run, so its footer waits rather than move later.
    const held =
      runs && this.#canGrow()
        ? this.#trailingRun(
            loaded.map((option) => this.#recordOf(option)),
            runs
          )
        : undefined;
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
    // Taken before held options are hidden, so an extra keeps what its source shows either way.
    const listed = this.#byKey(options);
    options = options.filter(include);

    this.#assertDistinctExtras(
      rawExtra,
      options.map((option) => originals.get(option) ?? option)
    );
    const allExtra = rawExtra.map((extra) =>
      this.#normalizeExtra(extra, listed, byOption, this.#resolvedOptionFor)
    );
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
    // Positioned options are hoisted out of both the extras and the source options before
    // grouping, which never reaches them: sticky ones lead the whole list, ahead of the none
    // option, and end ones follow everything else.
    const isSticky = (option: SelectOption) => option.position === "sticky";
    const isEnd = (option: SelectOption) => option.position === "end";
    const sticky = [...extra, ...options].filter(isSticky);
    const end = [...extra, ...options].filter(isEnd);
    options = options.filter((option) => option.position == null);
    const sourceCount = options.length;

    // Only source options are grouped; the create option belongs to no group.
    const grouped: GroupedRows = this.#shouldGroup()
      ? this.#groupOptions(options, runs, held, extending)
      : { rows: options.map((option) => ({ option })), actions: 0 };

    const none = this.#noneOption();
    const scrollingExtra = extra.filter((option) => option.position == null);
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
    const endOptions = this.#endOptions(end, rows, filter);
    rows.push(...endOptions.shown.map((option) => ({ option })));

    return this.#describeList(
      this.#placeDividers(rows, sticky.length),
      leading.length + endOptions.counted,
      sourceCount,
      rawCount,
      create,
      grouped,
      byOption
    );
  }

  /**
   * The options a paste can match among `inputs`, listed as the list would show them now: after
   * content steps, the legacy bridge and the extra options, each with its resolved option. Built afresh, so
   * it never reflects a list built earlier.
   *
   * @param inputs - Options the source holds, as a list would be built from them.
   */
  pasteOptions(inputs: readonly SelectOption[]): PasteOption[] {
    const byOption = new Map<SelectOption, SelectResolvedOption>();
    const before = this.#byKey(inputs);
    const rawExtra = this.#wrapExtras(this.#snapshot());
    const resolvedOf = this.#unlessShadowed(rawExtra, this.#peekOption);
    const options = this.#content(inputs).map((option) =>
      this.#normalize(option, before, byOption, resolvedOf)
    );
    const listed = this.#byKey(options);
    const extra = rawExtra.map((option) =>
      this.#normalizeExtra(option, listed, byOption, this.#peekOption)
    );
    const extraKeys = new Set(extra.map((option) => this.#keyOf(option)));
    return [
      ...extra,
      ...options.filter((option) => {
        const key = this.#keyOf(option);
        return key == null || !extraKeys.has(key);
      }),
    ].map((option) => ({
      option,
      resolved: byOption.get(option) ?? this.#rowOption(option),
    }));
  }

  /**
   * The held options as they stand at rest, by key: native content steps over the held inputs,
   * then the extras at rest over what content made. Each input already stands for its key's
   * record, which nothing here replaces: what a copy shows differently is kept as presentation,
   * and an input a step drops is kept as it was, because it is still held. The legacy bridge
   * never runs here.
   *
   * @param inputs - One option per held key, over the key's record.
   * @param context - The content context at rest: an empty filter and an at-rest control.
   * @param extras - The extras at rest, wrapped.
   */
  heldOptions(
    inputs: readonly SelectOption[],
    context: SelectContentContext,
    extras: readonly SelectOption[]
  ): Map<string, SelectOption> {
    const held = this.#byKey(inputs);
    const out = new Map<string, SelectOption>();
    for (const option of this.#applyContent([...inputs], context)) {
      const key = this.#keyOf(option);
      const input = key == null ? undefined : held.get(key);
      if (!input || out.has(key!) || optionKind(option) !== "value") {
        continue;
      }
      out.set(key!, this.#onRecord(input.record, option, input.record));
    }
    for (const [key, input] of held) {
      if (!out.has(key)) {
        out.set(key, input);
      }
    }
    for (const extra of extras) {
      const key = this.#keyOf(extra);
      const base = key == null ? undefined : out.get(key);
      if (!base || optionKind(extra) !== "value") {
        continue;
      }
      const kept: Record<string, unknown> = { ...base.settings };
      delete kept.position;
      delete kept.divider;
      const changed =
        extra.record === base.record
          ? undefined
          : this.#args.changedPresentation(base.record, extra.record);
      out.set(
        key!,
        selectOption(base.record, { ...kept, ...changed, ...extra.settings })
      );
    }
    return out;
  }

  /**
   * The held records as the trigger and chips list them: each with its key and value only, so
   * held async data never reads presentation or list state. Surfaces read the resolved option for a record
   * outside the data.
   *
   * @param records - The held records.
   */
  describeRecords(records: SelectRecord[]): readonly SelectHeldRow[] {
    return Object.freeze(
      records.map((record, index) => {
        const value = this.#args.recordValue(record);
        const key = this.#args.valueKey(value);
        return Object.freeze({
          key: key == null ? engineKey(`row:${index}`) : recordKey(key),
          value,
          record,
        });
      })
    );
  }

  /**
   * The extra options as they stand at rest, for an empty query whatever the live one is, so a
   * held value an extra stands for resolves to it while the user types.
   */
  extraOptionsAtRest(): SelectOption[] {
    // Built without reading the live filter, so typing never re-runs a held value's lookup.
    return this.#wrapExtras(
      Object.freeze({
        filter: "",
        value: this.#getValue(),
        hasValue: this.#getHasValue(),
      })
    );
  }

  /**
   * The end options this build shows, and how many the set size counts. While the source can
   * still grow they wait for its last option, still counted, as a pinned sticky option is, so
   * the size never jumps. With nothing else to show they show under an empty query, so the list
   * stays mounted and can page, and never under a query, where Enter would run the only option
   * left.
   */
  #endOptions(
    end: SelectOption[],
    rows: PlacedRow[],
    filter: string
  ): { shown: SelectOption[]; counted: number } {
    if (!rows.some((row) => !this.#isStructural(row.option))) {
      const shown = filter === "" ? end : [];
      return { shown, counted: shown.length };
    }
    return { shown: this.#canGrow() ? [] : end, counted: end.length };
  }

  /**
   * Draws the rules options asked for, at most one per gap: a group's splitter wins, then the
   * next option's "before", then the previous option's "after". A rule needs an option on both
   * sides, so none sits at either edge; none sits at the sticky seam, which the last sticky
   * option draws itself, or before a text group header, which draws its own. A rule between two
   * sticky options pins with them.
   */
  #placeDividers(rows: PlacedRow[], stickyCount: number): PlacedRow[] {
    const out: PlacedRow[] = [];
    rows.forEach((row, index) => {
      const previous = out.at(-1);
      if (
        previous &&
        !previous.splitter &&
        !previous.divider &&
        !row.splitter &&
        !this.#seamBetween(index - 1, index, stickyCount) &&
        !(row.boundary?.side === "header" && !row.boundary.action)
      ) {
        const owner = this.#dividerOwner(previous, row, index);
        if (owner) {
          const ownerKey = this.#rowKey(
            owner.row,
            this.#args.recordValue(owner.row.option.record),
            owner.index
          );
          out.push({
            option: engineOption("divider", Object.freeze({})),
            divider: {
              key: engineKey(`${owner.tag}:${ownerKey}`),
              sticky: index < stickyCount,
            },
          });
        }
      }
      out.push({ ...row, at: index });
    });
    return out;
  }

  /** The option a rule between `previous` and `next` belongs to, and where it sits. */
  #dividerOwner(
    previous: PlacedRow,
    next: PlacedRow,
    index: number
  ): { row: PlacedRow; index: number; tag: "db" | "da" } | null {
    if (next.option.divider === "before") {
      return { row: next, index, tag: "db" };
    }
    if (previous.option.divider === "after") {
      return { row: previous, index: index - 1, tag: "da" };
    }
    return null;
  }

  /** Whether the gap before `index` is where the sticky options end. */
  #seamBetween(previous: number, index: number, stickyCount: number): boolean {
    return previous < stickyCount && index >= stickyCount;
  }

  /** The value key an option is listed under, or `null` for a value-less option. */
  #keyOf(option: SelectOption): string | null {
    return this.#args.valueKey(this.#args.recordValue(option.record));
  }

  /** Asserts that no extra option lists a record the source also lists. */
  #assertDistinctExtras(
    extra: readonly SelectOption[],
    sourceOptions: readonly SelectOption[]
  ): void {
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
  }

  /** A resolved option lookup that skips the keys the given extra options take over. */
  #unlessShadowed(
    extra: readonly SelectOption[],
    resolvedOf: ResolvedLookup
  ): ResolvedLookup {
    const keys = new Set(extra.map((option) => this.#keyOf(option)));
    return (key, input) => (keys.has(key) ? undefined : resolvedOf(key, input));
  }

  #wrapExtras(snapshot: SelectSnapshot): SelectOption[] {
    const entries = makeArray(
      this.#args.extraOptions?.(snapshot, this.#args.config) ?? []
    ) as SelectOptionLike[];
    const keys = new Set<string>();
    return entries
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
  }

  /**
   * Describes the leading options, create, the grouped source rows and the end options, with
   * `besideSourceCount` options counted outside the source (leading and end, shown or held),
   * and stamps each OPTION with its position in the whole result set. Positions come from the engine's own totals rather
   * than the DOM index, so they stay correct while only a window is mounted, and they count
   * options only: an interleaved header or divider shifts no option's `posInSet` and never enters
   * `setSize`. A group's action header or footer is an option, so it is numbered and counted,
   * but never by paging.
   */
  #describeList(
    rows: PlacedRow[],
    besideSourceCount: number,
    sourceCount: number,
    inputCount: number,
    create: SelectOption | null,
    grouped: GroupedRows,
    byOption: ReadonlyMap<SelectOption, SelectResolvedOption>
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
      besideSourceCount + sourceTotal + (create ? 1 : 0) + grouped.actions;

    // Hoisted: the cap is a property of the selection, not of a row, and `#atMaximum` reads the
    // deduped value array — so evaluating it per row would repeat that work for every option.
    const atMaximum = this.#getAtMaximum();

    let optionOrdinal = 0;
    let logicalIndex = 0;
    const shown = new Set<string>();
    const described = Object.freeze(
      rows.map((placed, index) => {
        const row = {
          ...this.#describe(placed, index, atMaximum),
          resolved: this.#resolvedOf(placed, byOption, shown),
        };
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
    this.#keepOptions(shown);
    return described;
  }

  /**
   * The resolved option a placed row shows: its key's, for an option that stands for a value, and its own
   * option's for every row kind the engine builds.
   */
  #resolvedOf(
    placed: PlacedRow,
    byOption: ReadonlyMap<SelectOption, SelectResolvedOption>,
    shown: Set<string>
  ): SelectResolvedOption {
    const resolved = placed.boundary ? undefined : byOption.get(placed.option);
    if (resolved?.key != null) {
      shown.add(resolved.key);
      return resolved;
    }
    return this.#rowOption(placed.option);
  }

  /** Content steps, then the compatibility bridge's legacy content. */
  #content(loaded: readonly SelectOption[]): SelectOption[] {
    const options = this.#applyContent([...loaded], {
      filter: this.#getFilter(),
      value: this.#getValue(),
      ...this.#getContentContext(),
    });
    // Legacy `modifySelectKit(id).{prepend,append,replace}Content` extensions run in
    // their own stage, after native customizations, so ordering is deterministic and
    // does not depend on global registration order.
    return this.#applyLegacyContent(options);
  }

  /**
   * `option` over `record`, with what it shows differently from `made` as presentation its own
   * settings outrank.
   */
  #onRecord(
    record: SelectRecord,
    option: SelectOption,
    made: SelectRecord
  ): SelectOption {
    const changed =
      option.record === made
        ? undefined
        : this.#args.changedPresentation(made, option.record);
    return record === option.record && !changed
      ? option
      : selectOption(record, { ...changed, ...option.settings });
  }

  /** The first option listed for each key. */
  #byKey(options: readonly SelectOption[]): Map<string, SelectOption> {
    const byKey = new Map<string, SelectOption>();
    for (const option of options) {
      const key = this.#keyOf(option);
      if (key != null && !byKey.has(key)) {
        byKey.set(key, option);
      }
    }
    return byKey;
  }

  /** The record an option's key stands for in the list. */
  #recordOf(option: SelectOption): SelectRecord {
    const key = this.#keyOf(option);
    return (key != null && this.#viewRecord(key, option)) || option.record;
  }

  /**
   * The option over the record its key stands for, so grouping, runs and every data edge read
   * one record, and with the behaviour its resolved option merged from every source. A copy a content step
   * made contributes the presentation it changed from what it was made from: the listed option
   * of its key, or the key's record when none was listed. The copy's own settings outrank that.
   */
  #normalize(
    option: SelectOption,
    before: ReadonlyMap<string, SelectOption>,
    byOption: Map<SelectOption, SelectResolvedOption>,
    resolvedOf: ResolvedLookup
  ): SelectOption {
    const key = this.#keyOf(option);
    if (key == null || optionKind(option) !== "value") {
      return option;
    }
    const record = this.#viewRecord(key, option) ?? option.record;
    const made = before.get(key)?.record ?? record;
    return this.#withResolved(
      key,
      this.#onRecord(record, option, made),
      byOption,
      resolvedOf
    );
  }

  /**
   * An extra option over its key's record. It takes the slot of a listed option with its key,
   * whose resolved option properties it keeps wherever it is silent; placement stays its own. Like a content
   * copy, a different record of that key contributes the presentation it shows differently.
   */
  #normalizeExtra(
    extra: SelectOption,
    listed: ReadonlyMap<string, SelectOption>,
    byOption: Map<SelectOption, SelectResolvedOption>,
    resolvedOf: ResolvedLookup
  ): SelectOption {
    const key = this.#keyOf(extra);
    if (key == null || optionKind(extra) !== "value") {
      return extra;
    }
    const record = this.#viewRecord(key, extra) ?? extra.record;
    const shadowed = listed.get(key);
    let view = extra;
    if (record !== extra.record || shadowed) {
      const kept: Record<string, unknown> = { ...shadowed?.settings };
      delete kept.position;
      delete kept.divider;
      const changed =
        record === extra.record
          ? undefined
          : this.#args.changedPresentation(record, extra.record);
      view = selectOption(record, { ...kept, ...changed, ...extra.settings });
    }
    return this.#withResolved(key, view, byOption, resolvedOf);
  }

  /**
   * Looks the view's resolved option up and returns the option the row acts through: the view, carrying
   * the disabled state and action the resolved option merged.
   */
  #withResolved(
    key: string,
    view: SelectOption,
    byOption: Map<SelectOption, SelectResolvedOption>,
    resolvedOf: ResolvedLookup
  ): SelectOption {
    const resolved = resolvedOf(key, view);
    if (!resolved) {
      return view;
    }
    const acting =
      resolved.disabled === view.disabled &&
      resolved.action === (view.settings.onSelect ?? undefined)
        ? view
        : view.with({
            disabled: resolved.disabled ? true : null,
            onSelect: resolved.action ?? null,
          });
    byOption.set(acting, resolved);
    return acting;
  }

  #createOption(options: SelectOption[], filter: string): SelectOption | null {
    // At the cap nothing can be added, so a create row would only be a disabled suggestion.
    if (!filter || !this.#args.createOption || this.#getAtMaximum()) {
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

  #describe(
    placed: PlacedRow,
    index: number,
    atMaximum: boolean
  ): Omit<SelectRow, "resolved"> {
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
      group: boundary ? Object.freeze({ key: boundary.group.key }) : undefined,
      flags: {
        selected,
        sticky: placed.divider
          ? placed.divider.sticky
          : option.position === "sticky" && !structural && !boundary,
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
    if (placed.divider) {
      return placed.divider.key;
    }
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
    return key == null
      ? engineKey(`row:${placed.at ?? index}`)
      : recordKey(key);
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
          Object.freeze({ label: result }),
          { label: result }
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
    loaded: SelectRecord[],
    runs: Map<SelectRecord, GroupRun>
  ): GroupRun | undefined {
    for (let index = loaded.length - 1; index >= 0; index--) {
      const run = runs.get(loaded[index]);
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
      if (option.position != null) {
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
