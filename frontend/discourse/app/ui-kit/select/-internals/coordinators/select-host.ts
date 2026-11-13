import { tracked } from "@glimmer/tracking";
import { associateDestroyableChild, isDestroying } from "@ember/destroyable";
import { action } from "@ember/object";
import type Owner from "@ember/owner";
import { cancel, schedule } from "@ember/runloop";
import { modifier } from "ember-modifier";
import { makeArray } from "discourse/lib/helpers";
import type A11yService from "discourse/services/a11y";
import LoadFeedbackTracker from "discourse/ui-kit/select/-internals/coordinators/load-feedback";
import SelectAnnouncer from "discourse/ui-kit/select/-internals/coordinators/select-announcer";
import type {
  OptionsPresenter,
  SelectPresenterArgs,
} from "discourse/ui-kit/select/-internals/coordinators/select-presenter-base";
import WindowedListCoordinator from "discourse/ui-kit/select/-internals/coordinators/windowed-list-coordinator";
import type { SelectConfig } from "discourse/ui-kit/select/-internals/engine/customizations";
import type { SelectListContent } from "discourse/ui-kit/select/-internals/parts/select-list-body";
import SelectEngine, {
  type SelectEngineInit,
  type SelectLoadRequest,
  type SelectOptionLike,
  type SelectRecord as SelectRecordModel,
  type SelectRow,
  type SelectValue,
} from "discourse/ui-kit/select/select-engine";

/** Snapshot supplied to a paste parser before its asynchronous work begins. */
export interface SelectPasteContext {
  /** The current query text. */
  filter: string;
  /** The select's resolved presentation and recipe config. */
  config: SelectConfig;
  /** The current controlled selection. */
  value: SelectValue;
}

/** Arguments consumed by the shared select host. */
export interface SelectHostArgs
  extends
    SelectPresenterArgs,
    Pick<
      SelectEngineInit,
      | "kind"
      | "identifier"
      | "kindConfig"
      | "kindTexts"
      | "kindTextWrappers"
      | "minChars"
      | "maxLoaded"
      | "maximum"
      | "minimum"
      | "lockedValues"
      | "options"
      | "load"
      | "loadContext"
      | "filterBy"
      | "valueField"
      | "normalizeKey"
      | "labelField"
      | "valueRecords"
      | "resolveValue"
      | "resolveValues"
      | "allowCreate"
      | "createOption"
      | "createUnresolvedRecord"
      | "extraOptions"
      | "groupBy"
      | "groupDividers"
      | "groupHeader"
      | "groupFooter"
      | "onChange"
    > {
  /** Recipe data passed to customizations. */
  kindContext?: object;
  /** Temporary aliases for the deprecated modifySelectKit bridge and legacy CSS. */
  legacyKind?: string | string[];
  /** Instance data passed to customizations. */
  instanceContext?: object;
  /** The current controlled selection. */
  value?: SelectValue;
  /** Omits held options from the composed list. */
  hideSelected?: boolean;
  /** Number of initial loading placeholders. */
  skeletonCount?: number;
  /** Parses pasted text into a selection batch. */
  parsePaste?: (
    text: string,
    context: SelectPasteContext
  ) =>
    | readonly SelectOptionLike[]
    | null
    | undefined
    | Promise<readonly SelectOptionLike[] | null | undefined>;
}

/** Hosting component callbacks; readers stay live across argument updates. */
export interface SelectHostInit {
  /** Owner used by compatibility callbacks. */
  owner: Owner | undefined;
  /** Shared screen-reader announcement service. */
  getA11y: () => A11yService;
  /** Reads current source, value and recipe arguments. */
  getArgs: () => SelectHostArgs;
  /** Reads presentation after construction of the engine. */
  getPresenter: () => OptionsPresenter;
  /** Whether list-state reports may speak. Defaults to always true. */
  canReport?: () => boolean;
  /** Whether selection accepts multiple values. */
  getMultiple: () => boolean | undefined;
  /** Whether deferred source-context checks still have authority. */
  isLive: () => boolean;
  /** Identity of the current interaction session. */
  session: () => unknown;
  /** Clears the engine query and the host's editing state together. */
  clearQuery: () => void;
  /** Requests dismissal when the host has an open overlay. */
  requestClose: () => void;
  /** Host-DOM anchor for compatibility callbacks. */
  getElement: () => HTMLElement | null;
  /** Stable listbox identity. */
  getListboxId: () => string;
  /** Whether list entry must move DOM focus into a modal. */
  isStaticModal: () => boolean;
  /** Whether cursor entry already conveys the result count. */
  shouldSuppressEntryCount: () => boolean;
  /** Whether a single-select pick is spoken, as no trigger reads it back. Defaults to false. */
  speaksSinglePick?: () => boolean;
}

/** Owns source, selection and list wiring shared by select components. */
export default class SelectHost {
  /**
   * The search the visible results are for. While a new search loads, the previous results stay
   * on screen and this keeps naming their search until the new results arrive.
   */
  @tracked query = "";

  /** Stable engine identity shared with parts and compatibility callbacks. */
  engine: SelectEngine;
  announcer: SelectAnnouncer;
  feedback: LoadFeedbackTracker;
  listbox: WindowedListCoordinator;

  /**
   * Reads selection labels after the trigger records synchronous resolution outcomes.
   * Sync cache reads track async arrivals without starting another resolution.
   */
  selectionHooks = modifier((element: HTMLElement) => {
    const value = this.engine.value;
    const values: unknown[] = makeArray(value);
    element.setAttribute("data-value", values.map(String).join(","));
    element.setAttribute(
      "data-name",
      values
        .map((id) =>
          this.engine.getSelectionLabel(this.engine.resolveSingleSync(id))
        )
        .join(",")
    );
  });

  /** Defers context checks so a reactive argument never writes state during render. */
  watchLoadContext = modifier(() => {
    const context = this.#init.getArgs().loadContext ?? {};
    // Reading each entry subscribes the modifier to it.
    for (const key of Reflect.ownKeys(context)) {
      Reflect.get(context, key);
    }
    const session = this.#init.session();
    const check = schedule("afterRender", () => {
      if (
        !isDestroying(this) &&
        this.#init.isLive() &&
        this.#init.session() === session
      ) {
        this.engine.reloadIfContextChanged();
      }
    });
    return () => cancel(check);
  });

  #init: SelectHostInit;

  constructor(init: SelectHostInit) {
    this.#init = init;
    const legacyKind = init.getArgs().legacyKind;
    this.engine = new SelectEngine({
      // Read lazily so the engine reflects the parent's (reactive) @value — controlled.
      getValue: () => this.#init.getArgs().value,
      getHideSelected: () => this.#init.getArgs().hideSelected,
      getLocked: () => this.#init.getPresenter().isLocked,
      // Live readers for the reactive inputs, so a runtime change to any of these args
      // propagates into the engine (which reads them on every access). Static-by-contract
      // args below are passed by value.
      getMultiple: () => this.#init.getMultiple(),
      kind: this.#init.getArgs().kind,
      legacyKinds: makeArray(legacyKind),
      identifier: this.#init.getArgs().identifier,
      getKindContext: () => this.#init.getArgs().kindContext,
      getKindConfig: () => this.#init.getArgs().kindConfig,
      getTexts: () => this.#init.getArgs().texts,
      kindTexts: this.#init.getArgs().kindTexts,
      getKindTexts: () => this.#init.getArgs().kindTexts,
      kindTextWrappers: this.#init.getArgs().kindTextWrappers,
      getKindTextWrappers: () => this.#init.getArgs().kindTextWrappers,
      getInstanceContext: () => this.#init.getArgs().instanceContext,
      getMinChars: () => this.#init.getArgs().minChars,
      getMaxLoaded: () => this.#init.getArgs().maxLoaded,
      getMaximum: () => this.#init.getArgs().maximum,
      getLockedValues: () => this.#init.getArgs().lockedValues,
      getMinimum: () => this.#init.getArgs().minimum,
      getArgs: () => this.#init.getArgs(),
      options: (config) => {
        const args = this.#init.getArgs();
        return typeof args.options === "function"
          ? args.options(config)
          : args.options;
      },
      load: this.#init.getArgs().load,
      getLoadContext: () => this.#init.getArgs().loadContext,
      onReloadList: () => this.announcer.reloadList(),
      filterBy: this.#init.getArgs().filterBy,
      valueField: this.#init.getArgs().valueField,
      normalizeKey: this.#init.getArgs().normalizeKey,
      labelField: this.#init.getArgs().labelField,
      // Passed only when the consumer actually declared the arg. An arg that is present but
      // still empty is the late-arrival pattern mid-flight; withholding the reader entirely is
      // what lets the engine tell that apart from "no identity mechanism was ever supplied".
      getValueRecords:
        "valueRecords" in this.#init.getArgs()
          ? () => this.#init.getArgs().valueRecords
          : undefined,
      resolveValue: this.#init.getArgs().resolveValue,
      resolveValues: this.#init.getArgs().resolveValues,
      getAllowCreate: () => this.#init.getArgs().allowCreate,
      createOption: this.#init.getArgs().createOption,
      createUnresolvedRecord: this.#init.getArgs().createUnresolvedRecord,
      extraOptions: this.#init.getArgs().extraOptions,
      groupBy: this.#init.getArgs().groupBy,
      groupDividers: this.#init.getArgs().groupDividers,
      groupHeader: this.#init.getArgs().groupHeader,
      groupFooter: this.#init.getArgs().groupFooter,
      onChange: this.handleChange,
      onReconfirm: (record, origin) => this.announcer.reconfirm(record, origin),
      onBulkUnchanged: (skipped) => this.announcer.bulkUnchanged(skipped),
      onUpdateStart: (isCurrent) => this.announcer.updateStarted(isCurrent),
      requestClose: () => this.#init.requestClose(),
      legacy: {
        owner: this.#init.owner,
        getElement: () => this.#init.getElement(),
        isDestroyed: () => isDestroying(this),
      },
    });
    this.feedback = new LoadFeedbackTracker({
      engine: this.engine,
      getFilterDebounceDelay: () =>
        this.#init.getPresenter().filterDebounceDelay,
      getSkeletonCountArg: () => this.#init.getArgs().skeletonCount,
    });

    this.listbox = new WindowedListCoordinator({
      engine: this.engine,
      feedback: this.feedback,
      onStillLoading: () => this.announcer.announceStillLoading(),
      getListboxId: () => this.#init.getListboxId(),
      isStaticModal: () => this.#init.isStaticModal(),
    });

    this.announcer = new SelectAnnouncer({
      a11y: this.#init.getA11y(),
      canReport: this.#init.canReport,
      engine: this.engine,
      getActiveOptionKey: () => this.listbox.activeOptionKey,
      reannounceActive: () => this.listbox.reannounceActive(),
      getShouldSuppressEntryCount: () => this.#init.shouldSuppressEntryCount(),
      isRevealDue: () => this.feedback.showRevealPlaceholder,
      speaksSinglePick: this.#init.speaksSinglePick,
    });
    associateDestroyableChild(this, this.engine);
    associateDestroyableChild(this, this.feedback);
    associateDestroyableChild(this, this.listbox);
    associateDestroyableChild(this, this.announcer);
  }

  /**
   * Composes an `aria-describedby` token list from the component's own description ids and the
   * consumer's `@describedBy`, dropping the empty ones.
   *
   * A merge rather than a fallback because both sides are real: the component describes its own
   * state (the chip-navigation hint, the resting selection) while a form describes the field
   * (its validation message). Letting either win silently discards the other, and the loss is
   * inaudible to anyone not using a screen reader.
   */
  describedBy(...ids: Array<string | undefined | false>): string | undefined {
    const tokens = ids.filter(Boolean);
    return tokens.length ? tokens.join(" ") : undefined;
  }

  @action
  loadListContent(
    context: unknown,
    opts?: SelectLoadRequest
  ): SelectListContent | Promise<SelectListContent> {
    const options = this.engine.loadOptions(context, opts);
    const report = (content: SelectListContent): SelectListContent => {
      if (!isDestroying(this) && !opts?.signal?.aborted) {
        this.query = content.filter;
      }
      return content;
    };
    // Stamped at resolve time, not call time: an aborted-then-superseded load never reaches
    // here, so the query read on resolution is the one these rows were fetched for.
    if (options instanceof Promise) {
      return options.then((loaded) =>
        report(
          Object.freeze({
            options: loaded,
            filter: this.engine.filter,
            query: this.engine.queryKey,
            context: this.engine.requestLoadContext,
          })
        )
      );
    }
    const content = Object.freeze({
      options,
      filter: this.engine.filter,
      query: this.engine.queryKey,
      context: this.engine.requestLoadContext,
    });
    // Local sources resolve during render, after the header and footer have read the query.
    schedule("afterRender", () => report(content));
    return content;
  }

  /**
   * Resolves the bound ids to chip descriptors for the multi trigger. Narrows to the
   * array form; an empty value returns `undefined` (→ `:empty`). Uncached ids resolve in a
   * single batch, and any id that can't resolve becomes an unresolved fallback chip
   * (never a hole). Normalizing to rows here (not in the template) means the chips
   * are built once per value change and stay referentially stable across re-renders.
   */
  @action
  resolveMulti(
    value: unknown,
    opts?: SelectLoadRequest
  ):
    | readonly SelectRow[]
    | Promise<readonly SelectRow[] | undefined>
    | undefined {
    const resolved = this.engine.resolveSelection(value as SelectValue, opts);
    if (resolved == null) {
      return undefined;
    }
    if (resolved instanceof Promise) {
      return resolved.then((records) =>
        records === undefined
          ? undefined
          : this.engine.describeRecords(records as SelectRecordModel[])
      );
    }
    return this.engine.describeRecords(resolved as SelectRecordModel[]);
  }

  /**
   * Resolves the single bound value to its one display record for the trigger
   * `DAsyncContent`. Narrows the engine's arity-union return to the single form; a `null`
   * value returns `undefined` (routed to `:empty`), while a held value that can't resolve
   * comes back as an unresolved fallback record rather than `undefined`.
   */
  @action
  resolveSingle(
    value: unknown,
    opts?: SelectLoadRequest
  ): SelectRecordModel | Promise<SelectRecordModel> {
    return this.engine.resolveSelection(value as SelectValue, opts) as
      | SelectRecordModel
      | Promise<SelectRecordModel>;
  }

  @action
  handleChange(
    nextValue: SelectValue,
    payload: SelectRecordModel | SelectRecordModel[] | null,
    change: Parameters<NonNullable<SelectEngineInit["onChange"]>>[2]
  ): void {
    // This must be read before forwarding because the parent applies nextValue synchronously.
    const oldValues = this.#init.getArgs().value;
    this.announcer.valueChanged(oldValues, nextValue, {
      ...change,
      onAddedWithQuery: () => {
        this.#init.clearQuery();
      },
    });
    this.#init.getArgs().onChange?.(nextValue, payload, change);
  }

  /** Consumes parsed pastes while keeping selection and query cleanup under one authority. */
  @action
  handlePaste(event: ClipboardEvent): void | Promise<void> {
    const args = this.#init.getArgs();
    const parsePaste =
      args.parsePaste ??
      (this.engine.multiple ? this.engine.parsePaste : undefined);
    if (this.#init.getPresenter().isLocked || !parsePaste) {
      return;
    }
    const session = this.#init.session();
    const query = this.engine.queryKey;
    const result = parsePaste(
      event.clipboardData?.getData("text/plain") ?? "",
      {
        filter: this.engine.filter,
        config: this.engine.config,
        value: this.engine.value,
      }
    );
    if (result == null) {
      return;
    }
    event.preventDefault();
    return this.engine.update(
      (scope) => {
        const apply = (
          entries: readonly SelectOptionLike[] | null | undefined
        ) => {
          if (entries == null || !scope.current) {
            return;
          }
          scope.selectMany(entries);
          // Middleware may synchronously replace the selection intent or edit the query.
          if (
            scope.current &&
            this.#init.session() === session &&
            this.engine.queryKey === query
          ) {
            this.announcer.suppressCount();
            this.#init.clearQuery();
          }
        };
        if (result instanceof Promise) {
          return result.then(apply);
        }
        apply(result);
      },
      { paste: true }
    );
  }
}
