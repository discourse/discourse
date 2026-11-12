import { DEBUG } from "@glimmer/env";
import { cached } from "@glimmer/tracking";
import { untrack } from "@glimmer/validator";
import { isDestroying, registerDestructor } from "@ember/destroyable";
import type Owner from "@ember/owner";
import { bind } from "discourse/lib/decorators";
import { makeArray } from "discourse/lib/helpers";
import SelectCustomizations, {
  type SelectConfig,
  type SelectOptionPresentation,
  type SelectPresentationArgs,
  type SelectResolvedContext,
} from "discourse/ui-kit/select/-internals/engine/customizations";
import ListComposer from "discourse/ui-kit/select/-internals/engine/list-composer";
import SelectArgsView from "discourse/ui-kit/select/-internals/engine/select-args";
import {
  type SelectOption,
  type SelectOptionLike,
} from "discourse/ui-kit/select/-internals/engine/select-option";
import {
  filterLocal,
  localOptions,
  LocalSource,
  PagedSource,
  type SelectSource,
  SelectState,
} from "discourse/ui-kit/select/-internals/engine/select-sources";
import {
  renderSelectText,
  type SelectKindTexts,
  type SelectTexts,
  type SelectTextWrapper,
} from "discourse/ui-kit/select/-internals/engine/select-texts";
import SelectionActions from "discourse/ui-kit/select/-internals/engine/selection-actions";
import ValueResolver from "discourse/ui-kit/select/-internals/engine/value-resolver";
import {
  applyLegacySelectKitContent,
  applyLegacySelectKitOnChange,
} from "discourse/ui-kit/select/-internals/modify-select-kit-bridge";
import SelectionUpdates, {
  type SelectionOrigin,
} from "./-internals/engine/selection-updates.ts";

/** Every text DSelect draws or speaks, and how recipes render them from a resolved snapshot. */
export {
  DEFAULT_SELECT_TEXTS,
  renderSelectText,
  type SelectCoreTextKey,
  type SelectCoreTexts,
  type SelectKindTexts,
  type SelectText,
  type SelectTextContext,
  type SelectTexts,
  type SelectTextValues,
  type SelectTextWrapper,
} from "discourse/ui-kit/select/-internals/engine/select-texts";

/** The frozen config snapshot recipes receive in their callbacks and blocks. */
export type { SelectConfig };

/** What the select lists, and how a record is given settings. */
export {
  recordOf,
  selectOption,
  type SelectOption,
  type SelectOptionDivider,
  type SelectOptionLike,
  type SelectOptionPosition,
  type SelectOptionSettings,
} from "discourse/ui-kit/select/-internals/engine/select-option";

/**
 * A single record's value id. Items carry arbitrary, dynamically-keyed fields, so the
 * value read out of a record is `unknown` rather than a fixed scalar type.
 */
export type SelectId = unknown;

/**
 * The controlled value: a single id (or `null`) for single-select, or a (frozen) id
 * array for multi-select.
 */
export type SelectValue = SelectId | readonly SelectId[] | null;

/**
 * The data an option stands for: what the caller passed, as it is. Its fields are addressed
 * through `valueField` and `labelField`; none of them changes how the option behaves, which only
 * its settings do (see {@link selectOption}).
 */
export interface SelectRecord {
  [key: string]: unknown;
}

/** What a group's boundary rows know about the group they belong to. */
export interface SelectGroupInfo {
  /** The group's key, as `groupBy` returned it. */
  readonly key: SelectId;
  /** Whether the boundary is an action option rather than text. */
  readonly action: boolean;
}

/**
 * One rendered line, computed as the final step before render (see
 * {@link SelectEngine#buildRows}): an option, or a line the engine draws between options. It
 * carries a stable `key` (never an index; models need no `id`), the `value` for selection, the
 * option and its record, and the row `flags` so components read state from one place.
 */
export interface SelectRow {
  /**
   * Stable `{{#each}}` key: the normalized value for a record, or an engine key (prefixed
   * `__ds:`) for a row the engine builds, such as a group row, which follows its group rather
   * than its position. A record key that already starts with the prefix is escaped.
   */
  key: string;
  /** The row's id (raw, from `valueField`). */
  value: SelectId;
  /** The record the row stands for, passed untouched to consumer blocks. */
  record: SelectRecord;
  /** The option behind the row, with its settings. */
  option: SelectOption;
  /** The group a boundary row belongs to; absent on every other row. */
  group?: SelectGroupInfo;
  /** Row state, centralized so the template and option component don't re-derive it. */
  flags: {
    /** Whether this row's value is part of the current selection. */
    selected: boolean;
    /** Whether this option stays at the top while the list scrolls. */
    sticky: boolean;
    /** Whether the row cannot be activated (guards both pointer and keyboard). */
    disabled: boolean;
    /** Whether the consumer marked the record disabled. */
    reasonDisabled: boolean;
    /** Whether the selection cap prevents adding this option. */
    capDisabled: boolean;
    /** Whether this held row is locked, so it can't be deselected. */
    locked: boolean;
    /** A group header, text or action. */
    groupHeader: boolean;
    /** A group footer, text or action. */
    groupFooter: boolean;
    /**
     * A text header or text footer: structural, so it is skipped by selection, navigation, and
     * the option-position math (no `posInSet`/`setSize`). Rendered outside the option set. An
     * action header or footer is an option instead.
     */
    textBoundary: boolean;
    /** A divider row: structural like a header, but presentational and label-less. */
    divider: boolean;
    /** An action option: it runs its `onSelect` and never becomes a value. */
    action: boolean;
    /** The option that creates a value from the query. */
    create: boolean;
    /** The fallback for a held value that could not be resolved; false on list rows. */
    unresolved: boolean;
    /** The single-select option that clears the value. */
    none: boolean;
  };
  /**
   * Zero-based position among all list options, including disabled rows. Structural rows and
   * trigger/chip descriptors leave it undefined.
   */
  logicalIndex?: number;
  /**
   * Zero-based ordinal of the row's group, dense over every group shown, headed or not. Every
   * row the grouping emits carries it except splitters; ungrouped rows leave it undefined.
   */
  groupOrdinal?: number;
  /** Which text boundaries the row's group has, so its rows can be described by them. */
  groupText?: { header: boolean; footer: boolean };
  /**
   * 1-based position in the whole result set, independent of how many rows are mounted.
   * Stamped by {@link SelectEngine#buildRows} only; the trigger/chip path leaves it
   * undefined.
   */
  posInSet?: number;
  /**
   * Size of the whole result set when a source reports or derives one, and otherwise the count
   * of rows loaded so far — a source mid-paging under `hasMore: true` with no `total`, or one
   * stopped by the barren-page brake. Never `-1`: the ARIA sentinel for an unknown size has no
   * consistent implementation, so an honest count of the reachable rows is preferred and the
   * "more exists" half is announced instead.
   */
  setSize?: number;
}

export function selectRecordLabel(
  record: SelectRecord | null | undefined,
  labelField = "name"
): string {
  return String(record?.[labelField] ?? "");
}

/** What a source (`load` / `resolveValue`) call is asked for. */
export interface SelectLoadRequest {
  /** Resolved core and recipe values, supplied by the select engine. */
  config?: SelectConfig;
  /** Shallow snapshot of `@loadContext`, shared by every page of this query. */
  context?: Readonly<Record<string, unknown>>;
  /** Maximum page length requested from a paginated source. */
  limit?: number;
  /** Raw source offset for a paginated request. */
  offset?: number;
  /** Opaque cursor returned by the previous successful page; cleared for a new query. */
  cursor?: unknown;
  /**
   * The 1-based page number for a source that pages by number: 1 on a query's first request,
   * then one more after each settled page, barren pages included. A failed or abandoned
   * request is asked again under the same number. Set for `load` only.
   */
  page?: number;
  /** Cancels a superseded request. */
  signal?: AbortSignal;
}

/** A page from a server-backed source, with optional pagination metadata. */
export interface SelectLoadResponse {
  /** The page returned for the requested offset: records, or records wrapped with settings. */
  options: SelectOptionLike[];
  /** Opaque continuation value passed unchanged to the next request as `opts.cursor`. */
  cursor?: unknown;
  /**
   * The source's true result count when available. This is a fact about the whole set and
   * is carried forward across responses for the current query. It also licenses another
   * fetch on its own: a total above the rows returned so far means more remain.
   */
  total?: number;
  /**
   * Whether another page exists. This applies only to this response and is not carried
   * forward. `true` promises the next requested offset will yield rows not already returned.
   *
   * **Omitting it means `false`.** A source that paginates must say so; one that stays silent
   * is taken at its word that the rows it returned are the whole set, and they are reported
   * as such through `aria-setsize`. Passing `false` explicitly is equivalent and allowed, so
   * a cursor API can forward its own flag unmodified.
   */
  hasMore?: boolean;
}

/** Shapes accepted from a select source. */
export type SelectLoadResult = SelectOptionLike[] | SelectLoadResponse;

/** A frozen read-only view of the engine state passed to an `extraOptions` builder. */
export interface SelectSnapshot {
  filter: string;
  value: SelectValue;
  hasValue: boolean;
}

/**
 * Read-only handles the `modifySelectKit` compat bridge needs to build its facade,
 * supplied by the component. Not part of the consumer-facing API.
 */
export interface SelectLegacyContext {
  owner?: Owner;
  getElement?: () => Element | null;
  isDestroyed?: () => boolean;
}

/** Options for {@link SelectControl#reload}. */
export interface SelectReloadRequest {
  /**
   * Shows the loading state at once instead of after the usual delay, for a reload that changes
   * what the list shows (a different source), where the current rows are already wrong.
   */
  immediate?: boolean;
}

/**
 * The live handle for action rows and content, options, load, and change customizations.
 * The object stays frozen for the select's life. Its methods are for event time,
 * never for render-time callbacks, and do nothing once the select is destroyed.
 */
export interface SelectControl {
  /** The held value. */
  readonly value: SelectValue;
  /** The current filter text. */
  readonly filter: string;
  /** Whether asynchronous update work is in flight. */
  readonly pending: boolean;
  /** Closes the overlay. */
  close(): void;
  /** Selects a record, honouring the settings of an option passed instead. */
  select(entry: SelectOptionLike): void;
  /** Adds eligible entries in one change, skipping disabled and action options; single-select chooses the first new one. */
  selectMany(entries: readonly SelectOptionLike[]): void;
  /** Removes a record if held; single-select clears its held record. */
  deselect(entry: SelectOptionLike): void;
  /** Clears a nonempty selection. */
  clear(): void;
  /** Starts a new query without superseding a pending update. */
  reload(request?: SelectReloadRequest): void;
  /** Runs event-time work with write authority until it ends or is superseded. */
  update(
    work: (scope: SelectUpdateScope) => void | Promise<void>
  ): Promise<void>;
}

/** The write authority and cancellation signal of one update, without overlay or update controls. */
export interface SelectUpdateScope {
  /**
   * Cancels work with an `AbortError` when superseded or destroyed.
   * Own writes, reloads, and a pure `current` read do not abort it.
   */
  readonly signal: AbortSignal;
  /** Whether this update still owns the live value. A pure read. */
  readonly current: boolean;
  /** Selects a record while current and unlocked. */
  select(entry: SelectOptionLike): void;
  /** Adds eligible entries in one change; single-select chooses the first new one. */
  selectMany(entries: readonly SelectOptionLike[]): void;
  /** Removes a held record while current and unlocked. */
  deselect(entry: SelectOptionLike): void;
  /** Clears a nonempty selection while current and unlocked. */
  clear(): void;
}

/**
 * Builds a group's header or footer from its key and surviving options: text, an action option,
 * or nullish for none.
 */
export type SelectGroupBoundaryBuilder = (
  key: SelectId,
  options: readonly SelectOption[],
  config: SelectConfig
) => string | SelectOption | null | undefined;

/**
 * What a {@link SelectEngine} is constructed with.
 *
 * Function-valued options are invoked with an unspecified receiver — read the provided
 * arguments, never `this`. Where a callback acts on the select, it is handed a
 * {@link SelectControl} (see {@link SelectOptionSettings#onSelect}).
 *
 * The `get*` reader options are the live counterparts of the plain option beside each:
 * they reflect runtime changes to the underlying `@arg`, while the plain static option
 * is a construction-time snapshot for direct,
 * non-reactive consumers. A component wires these to its live args; the engine re-applies
 * each default on read.
 */
/** Builds the held records from the resolved config. */
export type SelectValueRecordsBuilder = (
  config: SelectConfig
) => SelectRecord | SelectRecord[];

export interface SelectEngineInit {
  /** Multi-select when true (drives value shape, chips, and close-on-select). */
  multiple?: boolean;

  /** Omits held options when composing the list. Defaults to false. */
  hideSelected?: boolean;

  /** Live reader for {@link hideSelected}. */
  getHideSelected?: () => boolean | undefined;

  /**
   * `() => value` — reads the controlled value live (single: an id or `null`; multi: an
   * id array). Must read tracked state for changing values; a fixed value is also supported.
   * In-place array edits require a tracked collection. Untracked changes are unsupported.
   * Defaults to always-`null`.
   */
  getValue?: () => SelectValue;

  /** Live reader for whether scope writes are locked. Defaults to false. */
  getLocked?: () => boolean;

  /** Live reader for {@link multiple}. */
  getMultiple?: () => boolean | undefined;

  /** Live reader for {@link minChars}. */
  getMinChars?: () => number | undefined;

  /** Live reader for {@link maxLoaded}. */
  getMaxLoaded?: () => number | undefined;

  /** Live reader for {@link maximum}. */
  getMaximum?: () => number | false | undefined;

  /** Live reader for {@link minimum}. */
  getMinimum?: () => number | undefined;

  /** Live reader for {@link lockedValues}. */
  getLockedValues?: () => readonly SelectId[] | undefined;

  /** Live raw presentation args, read before any records, resolved selection, or lock state. */
  getArgs?: () => Readonly<SelectPresentationArgs>;

  /** Recipe config keys and base values; keys are fixed at construction. Requires `kind`. */
  kindConfig?: Record<string, unknown>;

  /** Live base values for {@link kindConfig}; the initial keys declare the schema. */
  getKindConfig?: () => Record<string, unknown> | undefined;

  /** Live reader for the call site's texts, the layer above the recipe's. */
  getTexts?: () => SelectTexts | undefined;

  /**
   * The recipe's texts: defaults for engine texts and the texts it declares. A recipe built on
   * another may pass a list, lowest first, so its functions can read or defer to the inner
   * recipe's entries (see {@link SelectKindTexts}). Its non-engine keys are fixed at
   * construction. Requires `kind`.
   */
  kindTexts?: SelectKindTexts;

  /** Live values for {@link kindTexts}; the initial keys declare the recipe's texts. */
  getKindTexts?: () => SelectKindTexts | undefined;

  /**
   * The recipe's final say over a text, applied once to the result of every layer. Keys are fixed
   * at construction; required texts can't be wrapped. Requires `kind`.
   */
  kindTextWrappers?: Readonly<Record<string, SelectTextWrapper | undefined>>;

  /** Live values for {@link kindTextWrappers}. */
  getKindTextWrappers?: () =>
    | Readonly<Record<string, SelectTextWrapper | undefined>>
    | undefined;

  /** Live reader for {@link valueRecords}. */
  getValueRecords?: () => SelectEngineInit["valueRecords"];

  /** Live reader for {@link allowCreate}. */
  getAllowCreate?: () => SelectEngineInit["allowCreate"];

  /** The recipe or family name, fixed at construction. */
  kind?: string;

  /** Temporary names for the deprecated modifySelectKit bridge and legacy CSS only. */
  legacyKinds?: string[];

  /** The call-site name, fixed at construction. */
  identifier?: string;

  /**
   * Live reader for the recipe's data, passed to customizations as `context.kindContext`.
   * This carries what the recipe knows, such as its scope.
   */
  getKindContext?: () => object | undefined;

  /**
   * Live reader for the call site's data, passed to customizations as `context.instanceContext`, such
   * as the topic being edited.
   */
  getInstanceContext?: () => object | undefined;

  /**
   * A static array (or `(config) => array`) of records and options — the client-only source.
   * Provide this or `load`, not both.
   */
  options?:
    | SelectOptionLike[]
    | ((config: SelectConfig) => SelectOptionLike[] | null | undefined);

  /**
   * `(filter, { signal, offset, limit, page, cursor, context, config }) => options | { options, total?, hasMore?, cursor? }`,
   * synchronously or as a promise. Pagination starts without a limit so the source defines
   * its page size.
   *
   * A response that declares neither `total` nor `hasMore` — including a bare array — is
   * taken as the complete set, so a paginating source **must** declare one of them or only
   * its first page is ever shown.
   *
   * Called after the current render, never inside it, so it may write tracked state. State it
   * reads is not tracked: a change to it never re-asks the source. Supply `loadContext`
   * for reactive inputs, or call `reload()` explicitly.
   */
  load?: (
    filter: string,
    opts: SelectLoadRequest
  ) => SelectLoadResult | Promise<SelectLoadResult>;

  /**
   * The loader inputs whose own keys and values determine whether the list reloads. An array
   * entry compares by its elements, one level deep; every other entry compares by identity.
   */
  loadContext?: Readonly<Record<string, unknown>>;

  /** Live reader for {@link loadContext}. */
  getLoadContext?: () => SelectEngineInit["loadContext"];

  /** Called when a list reload invalidates result announcements. */
  onReloadList?: () => void;

  /**
   * Client-filter field name or `(record, term, config) => boolean`. Defaults to a substring
   * match on `labelField`.
   */
  filterBy?:
    | string
    | ((record: SelectRecord, term: string, config: SelectConfig) => boolean);

  /**
   * Minimum filter length before the list searches, 2 or more. Omitted, any input searches;
   * a minimum of 1 would be the same, so it asserts. A query shorter than this — including
   * the empty query — is "below threshold": the list issues no source call and the component
   * shows a keep-typing hint. See {@link SelectEngine#belowMinChars}.
   */
  minChars?: number;

  /** Optional server row ceiling with a filter-to-narrow hint. Uncapped by default. */
  maxLoaded?: number;

  /**
   * Hard cap on a multi-select's selection count. Ignored when not `multiple`; `false` means
   * no cap. Numbers below `1` and NaN also mean no cap but warn once per engine in development.
   * At the cap every add is refused — pointer, keyboard, create-on-the-fly and
   * the compat bridge all reach the same guard — and every unselected ordinary option reports
   * itself disabled. See {@link SelectEngine#atMaximum}.
   *
   * The cap is measured against the value read at activation time, so it holds for a consumer
   * that applies the emitted value synchronously and by replacement (the contract this
   * controlled component already assumes). One that applies it asynchronously, or merges
   * additively, can still land over the cap: two activations racing a pending update both read
   * the pre-update value. The engine deliberately keeps no selection state of its own, so it
   * cannot reserve a pending slot. Count validation at submit time belongs to the consuming
   * form, not here.
   *
   * It never trims an existing value: a caller that arrives already over the cap keeps every
   * held id and can still remove them, because silently dropping data on mount is worse than
   * showing an over-cap selection.
   */
  maximum?: number | false;

  /**
   * Advisory minimum for a multi-select: it drives {@link SelectEngine#belowMinimum} and the
   * limit messaging only. It never blocks removal (only {@link lockedValues} does), so
   * enforcement stays with the consuming form.
   */
  minimum?: number;

  /**
   * Held ids of a multi-select that no change may drop, matched by key (see
   * {@link normalizeKey}). Removing one, clearing, and any change that would leave one out are
   * refused; clearing keeps them. They must be a subset of the held value, and the engine never
   * adds them: the caller keeps them in its value. They count toward {@link maximum}.
   * Development builds assert when the list isn't an array, isn't held, or is given to a
   * single select.
   */
  lockedValues?: readonly SelectId[];

  /** Field holding a record's value. Defaults to `"id"`. */
  valueField?: string;

  /**
   * Maps an id's string form to the key that decides whether two ids are the same option.
   * Without it, ids are the same only when their string forms match exactly, so `"sam"` and
   * `"Sam"` are two options. Pass one when the domain matches ids loosely, for example a
   * lowercasing one for usernames. Matching, de-duplication and held-value resolution use the
   * key; emitted values keep the spelling they arrived with. Read once, at construction.
   */
  normalizeKey?: (key: string) => string;

  /** Field holding a record's label. Defaults to `"name"`. */
  labelField?: string;

  /**
   * Already-resolved record(s) for the ids in `value`, so the trigger displays them without a
   * fetch. It selects nothing on its own: every entry is looked up BY `value`, so supplying
   * this without a matching `value` shows the placeholder.
   *
   * Unlike a resolver, it is read reactively, so records may arrive after mount — a consumer
   * loading them itself can hand them over when they land and every selection surface
   * refreshes. A resolver cannot do that: its outcome is cached, including the failure, and
   * only `reload()` retries it.
   *
   * A function receives the resolved config and returns the records, so a held record's name can
   * come from a text (`renderSelectText(options, key)`). It is rebuilt when the options or what
   * it reads change.
   */
  valueRecords?: SelectRecord | SelectRecord[] | SelectValueRecordsBuilder;

  /**
   * `(value, { signal, config }) => record | Promise<record>`, used to resolve a value id to its
   * display record when it isn't already known.
   */
  resolveValue?: (
    value: SelectId,
    opts: SelectLoadRequest
  ) => SelectRecord | Promise<SelectRecord | undefined> | undefined;

  /**
   * Batch counterpart to `resolveValue` for multi-select:
   * `(values, { signal, config }) => records | Promise<records>`. The engine calls it once for the uncached
   * ids (cached / seeded ids are skipped) so N chips never mean N requests. Omitted or errored
   * ids become fallbacks.
   */
  resolveValues?: (
    values: SelectId[],
    opts: SelectLoadRequest
  ) => SelectRecord[] | Promise<SelectRecord[]>;

  /**
   * Enables the create-on-the-fly option; a function `(filter, records, config) => boolean`
   * gates it dynamically against the displayed query and its loaded records.
   */
  allowCreate?:
    | boolean
    | ((
        filter: string,
        records: SelectRecord[],
        config: SelectConfig
      ) => boolean);

  /**
   * `(filter, config) => record` producing the record the create option stands for. Name it by
   * its value text; the engine makes it the create option and supplies the "Create" wording.
   */
  createOption?: (filter: string, config: SelectConfig) => SelectOptionLike;

  /**
   * `(value, config) => record` producing the fallback for a held id that could not be resolved,
   * so a recipe can name it (e.g. `Topic #123`) instead of showing the bare id. The engine copies
   * the result and knows the copy as unresolved (see {@link SelectEngine#isUnresolvedRecord}).
   * Defaults to the id itself on `labelField`.
   */
  createUnresolvedRecord?: (
    value: SelectId,
    config: SelectConfig
  ) => SelectRecord;

  /**
   * `(snapshot, config) => options` the select adds beside its source (e.g. an "uncategorized"
   * option or an action). They lead the list, and no query filters them.
   */
  extraOptions?: (
    snapshot: SelectSnapshot,
    config: SelectConfig
  ) => SelectOptionLike[];

  /** Adds the single-select option that clears the value, when no presentation arg says otherwise. */
  noneOption?: boolean;

  /**
   * Groups the filtered options by a record field name or `(record, config) => key`. A group without a
   * header of either kind gets an unlabeled divider, except at the head of the list or when
   * `groupDividers` is false. A client source merges every row of a key into one group; a
   * source that pages groups consecutive rows, so a later page only extends the last group or
   * adds new ones, and a key that comes back starts another group.
   */
  groupBy?: string | ((record: SelectRecord, config: SelectConfig) => SelectId);

  /**
   * Whether a group without a header gets a divider before it. Defaults to true; false groups
   * rows only to place their headers and footers, with no boundary drawn between groups. Read
   * once, like `groupBy`.
   */
  groupDividers?: boolean;

  /**
   * `(key, options, config) => text | actionOption | null` builds a group's header. Text renders
   * a presentational header; an action option renders a navigable action row. A group with no
   * header of either kind gets an unlabeled divider instead (see `groupDividers`). `options` are
   * the group's surviving options, frozen; for the last group of a source that pages, the
   * options loaded so far. Runs during render, so it must be pure, and it must return nullish
   * for an `undefined` key.
   */
  groupHeader?: SelectGroupBoundaryBuilder;

  /**
   * Builds a group's footer, with the same signature and results as `groupHeader`. For a
   * source that pages, the last group's footer waits until the source can no longer grow, so
   * rows already shown never move.
   */
  groupFooter?: SelectGroupBoundaryBuilder;

  /** Whether choosing a record closes the overlay. Defaults to `!multiple`. */
  closeOnSelect?: boolean;

  /**
   * `(nextValue, record|records, change) => void`, where `nextValue` is the id(s) and the second arg
   * is the resolved record(s), each matching the arity. The parent applies `nextValue` to
   * `@value`. The third argument carries origin, clear metadata, and the resolved config.
   */
  onChange?: (
    nextValue: SelectValue,
    records: SelectRecord | SelectRecord[] | null,
    change: {
      /** The programmatic intent behind this change, absent for hand picks. */
      origin?: SelectionOrigin;
      /** Marks a clear, which keeps any locked values, from removing a record. */
      reason?: "clear";
      /** The config snapshot shared with the change middleware. */
      config: SelectConfig;
    }
  ) => void;

  /** Called when a programmatic pick confirms an already held record. */
  onReconfirm?: (record: SelectRecord, origin: SelectionOrigin) => void;

  /** Called when a batch adds nothing because every eligible record was held or over the limit. */
  onBulkUnchanged?: (skipped: { held: number; limit: number }) => void;

  /** Called when asynchronous work becomes pending; the reader checks its authority. */
  onUpdateStart?: (isCurrent: () => boolean) => void;

  /**
   * Called by the engine to ask the overlay to close (wired by the component to the menu
   * instance).
   */
  requestClose?: () => void;

  /**
   * Handles for the `modifySelectKit` compat bridge, supplied by the component:
   * `{ owner, getElement, isDestroyed }`. Only needed when the select carries
   * a kind that legacy extensions may target.
   */
  legacy?: SelectLegacyContext | null;
}

/** The {@link SelectControl} an engine hands out, frozen and guarded against a destroyed select. */
class EngineControl implements SelectControl {
  #engine: SelectEngine;

  constructor(engine: SelectEngine) {
    this.#engine = engine;
    Object.freeze(this);
  }

  get value(): SelectValue {
    return this.#engine.value;
  }

  get filter(): string {
    return this.#engine.filter;
  }

  get pending(): boolean {
    return this.#engine.pending;
  }

  clear(): void {
    if (!isDestroying(this.#engine)) {
      this.#engine.clear({ programmatic: true });
    }
  }

  close(): void {
    if (!isDestroying(this.#engine)) {
      this.#engine.requestClose();
    }
  }

  deselect(entry: SelectOptionLike): void {
    if (!isDestroying(this.#engine)) {
      this.#engine.deselect(entry, { programmatic: true });
    }
  }

  /** Starts a new query while the select is alive, preserving update authority. */
  reload(request?: SelectReloadRequest): void {
    if (!isDestroying(this.#engine)) {
      this.#engine.reload(request);
    }
  }

  select(entry: SelectOptionLike): void {
    if (!isDestroying(this.#engine)) {
      this.#engine.select(entry, { programmatic: true });
    }
  }

  /** Adds a batch while the select is alive. */
  selectMany(entries: readonly SelectOptionLike[]): void {
    if (!isDestroying(this.#engine)) {
      this.#engine.selectMany(entries, { programmatic: true });
    }
  }

  update(
    work: (scope: SelectUpdateScope) => void | Promise<void>
  ): Promise<void> {
    return this.#engine.update(work);
  }
}

/**
 * Headless, DOM-free controller for the ui-kit select family. It is **controlled**:
 * the parent owns the value (`@value`), which the engine reads live via a `getValue`
 * thunk and never stores. The engine owns only internal UI state — the filter, a
 * reload nonce, and a resolved-item cache — plus the selection *logic*: it derives
 * `isSelected`/display from the value, builds the rendered record list (content
 * customizations + create-on-the-fly + special records), resolves a value id to its
 * display record(s), and emits `onChange(nextValue, record|records)` for the parent to apply.
 *
 * It renders nothing: `DSelect` and its internal parts drive the DOM from this public
 * API. Consumers and tests never touch the engine directly — they use `DSelect`'s args
 * and observe `onChange`/DOM. Internal parts receive the engine but only call its
 * public methods and read its frozen getters; there is no public mutable field.
 */
export default class SelectEngine {
  #state = new SelectState();

  // Fires the `@options`+`@load` misconfiguration warning at most once per engine.
  #dualSourceWarned = false;

  #args: SelectArgsView;
  #legacyKinds: readonly string[];
  #valueResolver: ValueResolver;
  #selectionActions: SelectionActions;
  #selectionUpdates: SelectionUpdates;
  #listComposer: ListComposer;
  #source!: SelectSource;
  #control: SelectControl;
  #getLoadContext: () => SelectEngineInit["loadContext"];
  #onReloadList?: () => void;
  #requestContextQuery?: string;
  #requestLoadContext?: Readonly<Record<string, unknown>>;

  /**
   * Copies of the snapshot's array entries, so a later check can tell an equal array derived
   * afresh from a changed one, even when the caller mutated the snapshotted array in place.
   */
  #requestContextArrays = new Map<PropertyKey, readonly unknown[]>();

  /** The query an immediate reload started, compared with the live {@link queryKey}. */
  #immediateQueryKey: string | null = null;

  /** Sealed declarations collected once, before source validation. */
  #customizations: SelectCustomizations;

  /**
   * @param opts - The engine's configuration; every field is documented on
   *   {@link SelectEngineInit}.
   */
  constructor(opts: SelectEngineInit = {}) {
    this.#legacyKinds = Object.freeze([...(opts.legacyKinds ?? [])]);
    this.#getLoadContext = opts.getLoadContext ?? (() => opts.loadContext);
    this.#onReloadList = opts.onReloadList;
    this.#args = new SelectArgsView(opts);
    this.#control = new EngineControl(this);
    this.#valueResolver = new ValueResolver({
      args: this.#args,
      knownRecords: () => this.#source.knownRecords(),
    });
    this.#selectionActions = new SelectionActions({
      args: this.#args,
      runChange: (defaultStep, context) =>
        this.#customizations.runChange(defaultStep, context),
      onIntent: (origin) => this.#selectionUpdates.handleIntent(origin),
      beforeEmit: (origin, value) =>
        this.#selectionUpdates.prepareEmit(origin, value),
      runAction: (option) =>
        option.settings.onSelect!(this.#control, option.record),
      getExtensionContext: () => ({
        ...this.#extensionContext(),
        control: this.#control,
      }),
      cacheResolved: (record) => this.#valueResolver.cacheResolved(record),
      resolveOneSync: (value) => this.#valueResolver.resolveOneSync(value),
      applyLegacyOnChange: (value, payload) =>
        applyLegacySelectKitOnChange(this, value, payload),
    });
    this.#selectionUpdates = new SelectionUpdates({
      engine: this,
      args: this.#args,
      state: this.#state,
      actions: this.#selectionActions,
    });
    registerDestructor(this, () => this.#selectionUpdates.supersede());
    this.#listComposer = new ListComposer({
      args: this.#args,
      applyContent: (options, context) =>
        this.#customizations.applyContent(options, context, (entry) =>
          this.#args.wrapEntry(entry)
        ),
      getFilter: () => this.#state.filter,
      getValue: () => this.value,
      getHasValue: () => this.hasValue,
      isSelected: (entry) => this.isSelected(entry),
      isLockedValue: (value) => this.isLockedValue(value),
      getAtMaximum: () => this.atMaximum,
      getTotal: () => this.total,
      noteVisible: (visible, input) => this.#source.noteVisible(visible, input),
      canGrow: () => this.#source.mayGrow(),
      applyLegacyContent: (options) =>
        applyLegacySelectKitContent(this, options, this.#args),
      getContentContext: () => ({
        ...this.#extensionContext(),
        control: this.#control,
      }),
    });
    this.#source = this.#args.load
      ? new PagedSource({
          resolveLoad: (filter) => this.#resolveLoad(filter),
          state: this.#state,
          getMaxLoaded: () => this.#args.maxLoaded,
          keyOf: (option) =>
            this.#args.valueKey(this.#args.recordValue(option.record)),
          wrap: (entries) => this.#args.wrapPage(entries),
        })
      : new LocalSource({
          filtered: () => this.filteredOptions,
          all: () => localOptions(this.#args),
        });
    this.#customizations = new SelectCustomizations(
      {
        kind: this.kind,
        identifier: this.identifier,
      },
      this.#args.kindConfig,
      {
        kindTexts: this.#args.kindTexts,
        kindTextWrappers: this.#args.kindTextWrappers,
      }
    );
    this.#args.attachResolvedOptions(() => this.config);
    // Catch a both-sources misconfiguration up front (before any menu opens); the same
    // check also runs per load for a live `options` source that turns non-empty later.
    this.#assertSingleSource();
    // Checked here, during render, because the resolver's own check runs inside an async
    // data source that turns a throw into a rejection instead of failing the render.
    if (DEBUG && this.hasValue) {
      this.#valueResolver.assertCanResolve(this.value);
    }
  }

  /** The current filter term. */
  get filter(): string {
    return this.#state.filter;
  }

  /** Identifies a query across its pages, including explicit reloads of the same filter. */
  get queryKey(): string {
    return JSON.stringify([this.#state.nonce, this.#state.filter]);
  }

  /**
   * Whether the current query came from `reload({ immediate: true })`, so its loading state
   * shows without the usual delay. Any later query, typed or reloaded, clears it.
   */
  get immediateLoadFeedback(): boolean {
    return (
      this.#immediateQueryKey !== null &&
      this.#immediateQueryKey === this.queryKey
    );
  }

  /** The most recently started query's loader inputs, distinct from retained displayed rows. */
  get requestLoadContext(): Readonly<Record<string, unknown>> | undefined {
    return this.#requestLoadContext;
  }

  /**
   * The controlled value, normalized and memoized from the consumer's tracked state.
   *
   * @returns A frozen id array (multiple) or a single id / `null`.
   */
  get value(): SelectValue {
    return this.#selectionActions.value;
  }

  /** One reactive options pass shared by the engine, presenter, and every rendered row. */
  @cached
  get config(): SelectConfig {
    const args = this.#args.presentationArgs;
    return this.#customizations.resolveOptions(
      {
        caretIcon: args.caretIcon,
        iconOnly: args.iconOnly,
        searchIcon: args.searchIcon,
        icon: args.icon,
        showCaret: args.showCaret,
        clearable: args.clearable,
        noneOption: args.noneOption ?? this.#args.noneOptionDefault,
        loadingStatus: args.loadingStatus,
        disabled: args.disabled,
      },
      this.#args.kindConfig,
      {
        kind: this.kind,
        identifier: this.identifier,
        kindContext: this.#args.kindContext,
        instanceContext: this.#args.instanceContext,
        value: this.value,
        control: this.#control,
      },
      {
        kindTexts: this.#args.kindTexts,
        texts: this.#args.texts,
        wrappers: this.#args.kindTextWrappers,
        multiple: this.multiple,
        labelledBy: !!args.ariaLabelledBy,
      }
    );
  }

  /** Whether anything is selected. */
  get hasValue(): boolean {
    return this.#selectionActions.hasValue;
  }

  /** Whether any non-null id in the normalized selection currently resolves as unresolved. */
  get hasUnresolvedSelection(): boolean {
    const value = this.value;
    const values = [...makeArray(value as SelectId | SelectId[])];
    return this.#valueResolver.hasUnresolved(values);
  }

  /** Whether the source is server-backed (drives debouncing). */
  get isAsync(): boolean {
    return this.#args.isAsync;
  }

  /** Whether the source's latest answer arrived without a promise. */
  get answersSynchronously(): boolean {
    return this.#source.answersSynchronously();
  }

  /** The minimum filter length before the list searches (`0` = no minimum). */
  get minChars(): number {
    return this.#args.minChars;
  }

  /**
   * Whether the current query is shorter than {@link minChars} — the "keep typing" state, in
   * which the list should not search. Reads the filter reactively, so the component's gate
   * re-evaluates as the user types. An empty query counts as below the threshold: with a
   * minimum set, opening should prompt for input, not load (and then hide) the whole list.
   */
  get belowMinChars(): boolean {
    return (
      this.#args.minChars > 0 && this.#state.filter.length < this.#args.minChars
    );
  }

  /** How many more characters are needed to reach {@link minChars} (reactive). */
  get remainingMinChars(): number {
    return Math.max(0, this.#args.minChars - this.#state.filter.length);
  }

  /** The multi-select selection cap, or `null` when uncapped (always `null` for single). */
  get maximum(): number | null {
    return this.#selectionActions.maximum;
  }

  /** The advisory multi-select minimum (`0` = none, and always `0` for single). */
  get minimum(): number {
    return this.#selectionActions.minimum;
  }

  /**
   * Whether the selection has reached {@link maximum}. At the cap no further record can be
   * added, and every unselected ordinary option reports itself disabled.
   */
  get atMaximum(): boolean {
    return this.#selectionActions.atMaximum;
  }

  /** Whether the selection is still short of the advisory {@link minimum}. */
  get belowMinimum(): boolean {
    return this.#selectionActions.belowMinimum;
  }

  /** The held count the limits are measured against: every held id, deduped. */
  get selectedCount(): number {
    return this.#selectionActions.selectedCount;
  }

  /** How many more records may still be added, or `undefined` when uncapped. */
  get remaining(): number | undefined {
    return this.#selectionActions.remaining;
  }

  /** Whether a held value can be removed: one that isn't in {@link SelectEngineInit#lockedValues}. */
  get hasRemovableValue(): boolean {
    return this.#selectionActions.hasRemovableValue;
  }

  /** Whether this is a multi-select. */
  get multiple(): boolean {
    return this.#args.multiple;
  }

  /** The recipe or family name captured at construction. */
  get kind(): string | undefined {
    return this.#args.kind;
  }

  /** Compatibility aliases captured at construction; never customization keys. */
  get legacyKinds(): readonly string[] {
    return this.#legacyKinds;
  }

  /** The call-site name captured at construction. */
  get identifier(): string | undefined {
    return this.#args.identifier;
  }

  /** The live handle for action rows and content, options, load, and change customizations. */
  get control(): SelectControl {
    return this.#control;
  }

  /** Whether asynchronous update work is in flight. */
  get pending(): boolean {
    return this.#selectionUpdates.pending;
  }

  /**
   * Whether a paste is resolving. The open list shows its loading state meanwhile, so no row
   * can be picked, and the held chips stay drawn.
   */
  get pastePending(): boolean {
    return this.#selectionUpdates.pastePending;
  }

  /**
   * Read-only handles the `modifySelectKit` compat bridge needs to build its facade
   * (owner, a live element accessor, a teardown check). Supplied by the component; not
   * part of the consumer-facing API.
   */
  get legacyContext(): SelectLegacyContext | null {
    return this.#args.legacy;
  }

  /**
   * A stable-until-invalidated context object for the list `DAsyncContent`. Its identity
   * changes when the filter, reload nonce, reveal cursor, or the effective local records
   * change, which is what makes the list re-fetch.
   *
   * `options` is read synchronously here on purpose: a client source that changes must restart
   * the list even on the debounced path, where the async function runs outside the cached
   * computation and so cannot autotrack the source itself. Reading it in this `@cached` getter
   * folds the options dependency into the context identity. Empty (and cheap) for a server
   * source.
   */
  @cached
  get loadContext(): {
    filter: string;
    nonce: number;
    reveal: number;
    options: readonly SelectOption[];
  } {
    return {
      filter: this.#state.filter,
      nonce: this.#state.nonce,
      reveal: this.#source.revealToken(),
      options: this.#source.reactiveOptions(),
    };
  }

  /**
   * The client list after `filterBy`. Deriving this is the engine's job, so it is exposed
   * rather than recomputed by each caller — and it is `@cached` so `total` and `loadOptions`
   * share one filter pass per render instead of each walking the list again. Empty for a
   * server source.
   */
  @cached
  get filteredOptions(): readonly SelectOption[] {
    // Copied AND frozen: `@cached` hands the same array to every reader in the render, so
    // mutating it would corrupt what the engine itself reads next. Matches `buildRows`, which
    // also yields a frozen projection.
    return Object.freeze([...filterLocal(this.#args, this.#state.filter)]);
  }

  /** Whether the current source can fetch another page within any configured ceiling. */
  get canRevealMore(): boolean {
    return this.#source.canRevealMore();
  }

  /** Whether rendering stopped at the cap while the source still has more results. */
  get atCapWithMore(): boolean {
    return this.#source.atCapWithMore();
  }

  /**
   * The true result count when the source makes it knowable.
   *
   * A reported `total` outranks the count of rows actually navigable, deliberately: the engine
   * cannot tell an honest total whose tail it has not fetched from an inflated one, so it
   * trusts the source. A source that declares 500 and holds 90 therefore reports 500.
   * Unavailable after consecutive reveals fail to add visible rows for the query.
   */
  get total(): number | undefined {
    return this.#source.total();
  }

  /**
   * How many SOURCE options are currently loaded — excludes specials and the create row, so it
   * shares `total`'s population and a footer's `total - loadedCount` is a valid "how many more".
   * Reads the live source count (a client source has them all; a paginating source has its
   * accumulated page count), so it stays correct even while the list is unmounted (min-chars /
   * error), unlike a render-time count of navigable rows.
   */
  get loadedCount(): number {
    return this.#args.isAsync
      ? this.#state.serverLoadedCount
      : (this.total ?? 0);
  }

  /**
   * Whether a **reload** of an already-settled list is in flight — a new query, a
   * `reload()`, or a reveal — which is what `aria-busy` on the retained listbox reports.
   * The *initial* load is deliberately not pending: the listbox does not exist yet then,
   * its loading block does.
   *
   * Derived from tracked state rather than an imperative flag, because the flag would have
   * to be raised synchronously inside `loadItems`, which runs during render, and so could
   * never invalidate a consumer that had already read it — `aria-busy` would switch off
   * but never on.
   */
  get serverPending(): boolean {
    return this.#source.pending();
  }

  /** Whether a server source has not finished its first page yet. */
  get serverAwaitingFirstPage(): boolean {
    return this.#source.awaitingFirstPage();
  }

  /**
   * Whether the in-flight load is fetching more rows for the query already on screen rather
   * than replacing them for a new one. Both retain the old rows, so only this tells them apart.
   */
  get serverRevealPending(): boolean {
    return this.#source.revealPending();
  }

  /**
   * Whether the in-flight load answers a new filter, the only load that waits for the
   * debounce. A reveal or a reload keeps the filter and starts at once.
   */
  get serverQueryPending(): boolean {
    return this.#source.queryPending();
  }

  /** Whether a held id is locked, matching by key; an unheld id never is. */
  isLockedValue(value: SelectId): boolean {
    return this.#selectionActions.isLockedValue(value);
  }

  /** Every id in `previous` that `next` no longer holds, matching by key, in held order. */
  removedValues(
    previous: readonly SelectId[],
    next: readonly SelectId[]
  ): SelectId[] {
    return this.#selectionActions.removedValues(previous, next);
  }

  /**
   * Finds the first value added and removed between two selections, comparing ids by
   * `String(value)`.
   */
  diffValues(
    previous: SelectId[],
    next: SelectId[]
  ): {
    added: SelectId | undefined;
    removed: SelectId | undefined;
  } {
    return this.#selectionActions.diffValues(previous, next);
  }

  /**
   * Renders a text from the resolved config: every layer, then the recipe's wrapper. Call it
   * where the text is drawn or spoken, so a text that reads live recipe state stays current.
   *
   * @param key - The text's key.
   * @param values - The values its translation interpolates.
   * @returns The text; `""` means the place shows nothing.
   */
  @bind
  text(key: string, values?: object): string {
    return renderSelectText(this.config, key, values);
  }

  /**
   * Whether a record or option is currently selected, comparing its record's `valueField` id
   * against the controlled value. The none option is selected while nothing is held.
   */
  @bind
  isSelected(entry: SelectOptionLike): boolean {
    return this.#selectionActions.isSelected(entry);
  }

  /**
   * The async-data function for the list `DAsyncContent`. Returns the full filtered local
   * list or the accumulated server pages, bounded by `maxLoaded` when configured.
   *
   * @param _context - Reactivity trigger only; unused.
   * @returns Options, or a promise of options.
   */
  @bind
  loadOptions(
    _context: unknown,
    opts: SelectLoadRequest = {}
  ): SelectOption[] | Promise<SelectOption[]> {
    this.#assertSingleSource();
    return this.#source.rows(opts);
  }

  /**
   * Requests another page when the source can reveal one.
   *
   * @returns Whether the reveal cursor advanced.
   */
  @bind
  revealMore(): boolean {
    return this.#source.revealMore();
  }

  /**
   * Builds the rendered rows from the source's options: applies content customizations, groups
   * the options, and adds the extra and create options.
   *
   * @param options - The options the source resolved; a bare record is an option with no settings.
   * @param filter - The query that produced them, retained for create checks during a reload.
   * @returns The frozen rows to render.
   */
  @bind
  buildRows(
    options: readonly SelectOptionLike[] = [],
    filter = this.filter
  ): readonly SelectRow[] {
    // The source's options arrive wrapped and unique; only a bare record still needs wrapping,
    // so a growing list is never re-keyed on every build.
    return this.#listComposer.buildRows(
      options.map((entry) => this.#args.wrapEntry(entry)),
      filter
    );
  }

  /**
   * Rows for held records, as the trigger and chips draw them.
   *
   * @param records - The held records.
   */
  @bind
  describeRecords(records: SelectRecord[]): readonly SelectRow[] {
    return this.#listComposer.describeRecords(records, (record) =>
      this.isUnresolvedRecord(record)
    );
  }

  /**
   * Resolves a value to its display record(s) for the trigger `DAsyncContent`. Returns
   * synchronously (no skeleton) when every id is covered by `valueRecords`,
   * the resolve cache, or the client list; otherwise returns a promise. A held id that
   * cannot resolve maps to a synthetic unresolved fallback (never `undefined`, never a
   * rejection, whether the resolver throws or rejects); only an empty value (null single /
   * empty multi) yields `undefined`, so the trigger shows its placeholder.
   *
   * Both arities share one path: single is a batch of one, narrowed back to a bare record so
   * the trigger never sees a one-element array. Whatever the sync ladder doesn't already
   * know resolves in a single call.
   *
   * @param value - The value (an id, or an array of ids).
   */
  @bind
  resolveSelection(
    value: SelectValue,
    opts: SelectLoadRequest = {}
  ):
    | SelectRecord
    | SelectRecord[]
    | Promise<SelectRecord>
    | Promise<SelectRecord[]>
    | Promise<void>
    | undefined {
    // A paste only adds to the held records, so they stay drawn while it resolves.
    const done = this.#selectionUpdates.pastePending
      ? undefined
      : this.#selectionUpdates.done;
    return done ?? this.#valueResolver.resolveSelection(value, opts);
  }

  /**
   * The record to display for a single value without awaiting — including the unresolved
   * fallback once an attempt has failed, so a trigger can tell "failed" (render the
   * fallback) from "still resolving" (`undefined`, render nothing).
   *
   * @param value - The single value; an array or `null` yields `undefined`.
   */
  resolveSingleSync(value: SelectValue): SelectRecord | undefined {
    return this.#valueResolver.resolveSingleSync(value);
  }

  getRecordLabel(record: SelectRecord | null | undefined): string {
    return selectRecordLabel(record, this.#args.labelField);
  }

  /**
   * The text that stands for a held record on every surface: the trigger, chips, the typeahead
   * input, the accessible names built from them, and announcements. An unresolved record named by
   * `createUnresolvedRecord` keeps that name, which already explains itself; the default fallback
   * reads as an unknown record with its id, since nothing more is known about it.
   *
   * @param record - The held record, resolved or not.
   * @returns The label to show and announce.
   */
  @bind
  getSelectionLabel(record: SelectRecord | null | undefined): string {
    if (
      record &&
      this.isUnresolvedRecord(record) &&
      !this.isCustomUnresolvedRecord(record)
    ) {
      return this.text("unresolvedValue", {
        value: String(record[this.#args.valueField] ?? ""),
      });
    }
    return this.getRecordLabel(record);
  }

  getSingleSelectionLabel(value: SelectValue): string {
    if (value == null || Array.isArray(value)) {
      return "";
    }

    return this.getRecordLabel(this.#valueResolver.resolveOneSync(value));
  }

  /**
   * Option presentation from render-time customizations. Each evaluation starts fresh
   * so classes and titles cannot leak between options or renders.
   *
   * @param row - The option's rendered row.
   */
  @bind
  optionPresentation(row: SelectRow): SelectOptionPresentation {
    return this.#customizations.applyOption({
      option: row.option,
      record: row.record,
      selected: row.flags.selected,
      disabled: row.flags.disabled,
      ...this.#extensionContext(),
    });
  }

  /**
   * Whether a record is the engine's fallback for a held value that could not be resolved. Only
   * the engine's own copies are; no field on a record can make it one.
   *
   * @param record - The record to test.
   */
  @bind
  isUnresolvedRecord(record: SelectRecord): boolean {
    return this.#valueResolver.isUnresolvedRecord(record);
  }

  /**
   * Whether this fallback came from `createUnresolvedRecord` rather than the built-in bare-id
   * default. Lets a trigger that can only render a string decide whether to append its own
   * "unavailable" wording: a named fallback ("Topic #123") already reads as one, a bare id
   * does not. Identity-based, so a builder that throws — caught, yielding the default — is
   * correctly reported as NOT custom.
   *
   * @param record - The record to test; only meaningful for an unresolved fallback.
   */
  isCustomUnresolvedRecord(record: SelectRecord): boolean {
    return this.#valueResolver.isCustomUnresolvedRecord(record);
  }

  /**
   * Sets the filter term (re-runs the list search).
   */
  @bind
  setFilter(term: string): void {
    const filter = term ?? "";
    if (filter === this.#state.filter) {
      return;
    }

    this.#source.reset();
    this.#state.filter = filter;
  }

  /**
   * Activates an option: runs its `onSelect` if it is an action (which never becomes a value
   * and does not close the overlay), otherwise toggles its record.
   */
  @bind
  activate(entry: SelectOptionLike): void {
    this.#selectionActions.activate(entry);
  }

  /**
   * Toggles a record: for multi, selects or deselects; for single, selects it.
   */
  @bind
  toggle(entry: SelectOptionLike): void {
    this.#selectionActions.toggle(entry);
  }

  /**
   * Selects a record: caches it for synchronous display, computes the next value, and emits
   * `onChange`. An option passed instead is honoured: a disabled one selects nothing, and an
   * action can't be selected. For single-select it also requests the overlay to close (when
   * `closeOnSelect`). Never mutates the value — the parent does, via `onChange`.
   */
  @bind
  select(entry: SelectOptionLike, origin?: SelectionOrigin): void {
    this.#selectionActions.select(entry, origin);
  }

  /**
   * Adds eligible entries with one middleware run and emit, up to the remaining capacity.
   * Skips held, duplicate, disabled, action and structural options. Single-select picks the
   * first new eligible one. Even an empty batch supersedes older update intent.
   */
  @bind
  selectMany(
    entries: readonly SelectOptionLike[],
    origin?: SelectionOrigin
  ): void {
    this.#selectionActions.selectMany(entries, origin);
  }

  /**
   * Removes a record from the selection (emits the next value).
   */
  @bind
  deselect(entry: SelectOptionLike, origin?: SelectionOrigin): void {
    this.#selectionActions.deselect(entry, origin);
  }

  /** Removes the last held value from a multi-select selection. */
  @bind
  deselectLast(origin?: SelectionOrigin): void {
    this.#selectionActions.deselectLast(origin);
  }

  /** Clears the selection down to its locked values; does nothing when only those are held. */
  @bind
  clear(origin?: SelectionOrigin): void {
    this.#selectionActions.clear(origin);
  }

  /** Revokes update authority when newer interaction intent takes over. */
  supersedeUpdate(): void {
    this.#selectionUpdates.supersede();
  }

  /**
   * Runs event-time work with a scope owned by this update.
   *
   * @param work - The update's work.
   * @param opts - `paste` marks the update as a paste (see `pastePending`).
   */
  update(
    work: (scope: SelectUpdateScope) => void | Promise<void>,
    opts?: { paste?: boolean }
  ): Promise<void> {
    return this.#selectionUpdates.update(work, opts);
  }

  /**
   * The paste parser a multi-select uses when the call site passes none. Two or more
   * `|`-separated names are matched against the options the source knows, by value or by label
   * ignoring case, and a name with no option is created where creation is allowed. A name that
   * matches a disabled or action option adds nothing. Anything else is left to the browser.
   *
   * @param text - The pasted plain text.
   */
  @bind
  parsePaste(text: string): SelectOption[] | null {
    const names = text
      .split("|")
      .map((name) => name.trim())
      .filter(Boolean);
    if (names.length < 2) {
      return null;
    }
    const args = this.#args;
    const known = this.#source.knownOptions();
    const records = known.map((option) => option.record);
    const allowCreate = args.allowCreate;
    return names
      .map((name) => {
        const term = name.toLowerCase();
        const match =
          known.find(
            (option) => args.valueKey(args.recordValue(option.record)) === name
          ) ??
          known.find(
            (option) =>
              String(args.recordLabel(option.record) ?? "").toLowerCase() ===
              term
          );
        if (match) {
          return match;
        }
        const creates =
          typeof allowCreate === "function"
            ? allowCreate(name, records, this.config)
            : !!allowCreate;
        return creates && args.createOption
          ? args.wrapEntry(args.createOption(name, this.config))
          : undefined;
      })
      .filter(
        (option): option is SelectOption =>
          option !== undefined && !option.disabled && !option.action
      );
  }

  /**
   * Resets the source and forces a re-fetch even when the filter is unchanged. Also
   * drops failed value-resolution fallbacks so they are attempted again; successful records
   * stay cached.
   */
  @bind
  reload(request?: SelectReloadRequest): void {
    this.#valueResolver.evictUnresolved();
    this.#reloadList();
    this.#immediateQueryKey = request?.immediate ? this.queryKey : null;
  }

  /** Checks live loader inputs at event time; never call during render. */
  reloadIfContextChanged(): void {
    if (isDestroying(this) || this.#requestContextQuery !== this.queryKey) {
      return;
    }
    const context = this.#getLoadContext() ?? {};
    const snapshot = this.#requestLoadContext ?? {};
    const keys = Reflect.ownKeys(context);
    if (
      keys.length !== Reflect.ownKeys(snapshot).length ||
      keys.some(
        (key) =>
          !Object.hasOwn(snapshot, key) ||
          this.#contextEntryChanged(key, Reflect.get(context, key), snapshot)
      )
    ) {
      this.#reloadList();
    }
  }

  /**
   * Asks the overlay to close (wired by the component). Used by action records and the
   * compat bridge's `selectKit.close()`.
   */
  @bind
  requestClose(): void {
    this.#args.requestClose?.();
  }

  #contextEntryChanged(
    key: PropertyKey,
    value: unknown,
    snapshot: Readonly<Record<string, unknown>>
  ): boolean {
    const copy = this.#requestContextArrays.get(key);
    if (!copy) {
      return !Object.is(value, Reflect.get(snapshot, key));
    }
    return (
      !Array.isArray(value) ||
      value.length !== copy.length ||
      value.some((element, index) => !Object.is(element, copy[index]))
    );
  }

  /** The static names and live data shared by select customizations. */
  #extensionContext(): SelectResolvedContext {
    return {
      kind: this.kind,
      identifier: this.identifier,
      kindContext: this.#args.kindContext,
      instanceContext: this.#args.instanceContext,
      config: this.config,
    };
  }

  /** Reloads only the list, preserving held-value fallbacks and pending update authority. */
  #reloadList(): void {
    this.#onReloadList?.();
    this.#source.reset();
    this.#state.nonce++;
  }

  /** Resolves the loader outside render when a query's first request starts. */
  #resolveLoad(filter: string): NonNullable<SelectEngineInit["load"]> {
    const context = this.#getLoadContext() ?? {};
    const snapshot: Readonly<Record<string, unknown>> = Object.freeze(
      Object.fromEntries(
        Reflect.ownKeys(context).map((key) => [key, Reflect.get(context, key)])
      )
    );
    this.#requestLoadContext = snapshot;
    this.#requestContextArrays = new Map(
      Reflect.ownKeys(snapshot).flatMap((key) => {
        const value: unknown = Reflect.get(snapshot, key);
        return Array.isArray(value) ? [[key, [...value]] as const] : [];
      })
    );
    this.#requestContextQuery = this.queryKey;
    const load = this.#customizations.applyLoad(
      this.#args.load!,
      {
        loadContext: snapshot,
        filter,
        ...this.#extensionContext(),
        control: this.#control,
      },
      (entry) => this.#args.wrapEntry(entry)
    );
    return (query, opts) =>
      load(query, {
        ...opts,
        context: snapshot,
        config: this.config,
      });
  }

  // `options` and `load` are mutually exclusive; the construction-time source kind wins.
  // Warns once when both are supplied — checked here rather than only in the constructor
  // because a live `options` source can turn non-empty after construction.
  #assertSingleSource(): void {
    if (this.#dualSourceWarned || !this.#args.isAsync) {
      return;
    }
    // Runs inside the list's load, so its reads must not become reload inputs: resolving the
    // options reads the recipe's context and presentation arguments, and a change to any of them
    // would cancel the page in flight.
    const local = untrack(() =>
      typeof this.#args.options === "function"
        ? this.#args.options(this.config)
        : this.#args.options
    );
    if (local != null && (makeArray(local) as unknown[]).length > 0) {
      this.#dualSourceWarned = true;
      // eslint-disable-next-line no-console
      console.warn(
        "DSelect: `@options` and `@load` are mutually exclusive; `@load` takes precedence and `@options` is ignored."
      );
    }
  }
}
