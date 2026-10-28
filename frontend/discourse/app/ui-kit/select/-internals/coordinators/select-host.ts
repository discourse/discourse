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
import type { SelectResolvedOptions } from "discourse/ui-kit/select/-internals/engine/customizations";
import type { SelectListContent } from "discourse/ui-kit/select/-internals/parts/select-options";
import SelectEngine, {
  type SelectDescriptor,
  type SelectEngineOptions,
  type SelectItem as SelectItemModel,
  type SelectLoadOptions,
  type SelectValue,
} from "discourse/ui-kit/select/select-engine";

/** Snapshot supplied to a paste parser before its asynchronous work begins. */
export interface SelectPasteContext {
  /** The current query text. */
  filter: string;
  /** The select's resolved presentation and recipe options. */
  options: SelectResolvedOptions;
  /** The current controlled selection. */
  value: SelectValue;
}

/** Arguments consumed by the shared select host. */
export interface SelectHostArgs
  extends
    SelectPresenterArgs,
    Pick<
      SelectEngineOptions,
      | "kind"
      | "identifier"
      | "kindOptions"
      | "minChars"
      | "maxLoaded"
      | "maximum"
      | "minimum"
      | "noneLabel"
      | "items"
      | "load"
      | "loadContext"
      | "filterBy"
      | "valueField"
      | "labelField"
      | "valueItems"
      | "resolveValue"
      | "resolveValues"
      | "allowCreate"
      | "createItem"
      | "createUnresolvedItem"
      | "specialItems"
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
  /** Label for an empty result set. */
  noResultsLabel?: string;
  /** Parses pasted text into a selection batch. */
  parsePaste?: (
    text: string,
    context: SelectPasteContext
  ) =>
    | readonly SelectItemModel[]
    | null
    | undefined
    | Promise<readonly SelectItemModel[] | null | undefined>;
}

/** Hosting component callbacks; readers stay live across argument updates. */
export interface SelectHostOptions {
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
    const context = this.#options.getArgs().loadContext ?? {};
    // Reading each entry subscribes the modifier to it.
    for (const key of Reflect.ownKeys(context)) {
      Reflect.get(context, key);
    }
    const session = this.#options.session();
    const check = schedule("afterRender", () => {
      if (
        !isDestroying(this) &&
        this.#options.isLive() &&
        this.#options.session() === session
      ) {
        this.engine.reloadIfContextChanged();
      }
    });
    return () => cancel(check);
  });

  #options: SelectHostOptions;

  constructor(options: SelectHostOptions) {
    this.#options = options;
    const legacyKind = options.getArgs().legacyKind;
    this.engine = new SelectEngine({
      // Read lazily so the engine reflects the parent's (reactive) @value — controlled.
      getValue: () => this.#options.getArgs().value,
      getHideSelected: () => this.#options.getArgs().hideSelected,
      getLocked: () => this.#options.getPresenter().isLocked,
      // Live readers for the reactive inputs, so a runtime change to any of these args
      // propagates into the engine (which reads them on every access). Static-by-contract
      // args below are passed by value.
      getMultiple: () => this.#options.getMultiple(),
      kind: this.#options.getArgs().kind,
      legacyKinds: makeArray(legacyKind),
      identifier: this.#options.getArgs().identifier,
      getKindContext: () => this.#options.getArgs().kindContext,
      getKindOptions: () => this.#options.getArgs().kindOptions,
      getInstanceContext: () => this.#options.getArgs().instanceContext,
      getMinChars: () => this.#options.getArgs().minChars,
      getMaxLoaded: () => this.#options.getArgs().maxLoaded,
      getMaximum: () => this.#options.getArgs().maximum,
      getMinimum: () => this.#options.getArgs().minimum,
      getNoneLabel: () => this.#options.getArgs().noneLabel,
      getOptions: () => this.#options.getArgs(),
      items: (resolvedOptions) => {
        const args = this.#options.getArgs();
        return typeof args.items === "function"
          ? args.items(resolvedOptions)
          : args.items;
      },
      load: this.#options.getArgs().load,
      getLoadContext: () => this.#options.getArgs().loadContext,
      onReloadList: () => this.announcer.reloadList(),
      filterBy: this.#options.getArgs().filterBy,
      valueField: this.#options.getArgs().valueField,
      labelField: this.#options.getArgs().labelField,
      // Passed only when the consumer actually declared the arg. An arg that is present but
      // still empty is the late-arrival pattern mid-flight; withholding the reader entirely is
      // what lets the engine tell that apart from "no identity mechanism was ever supplied".
      getValueItems:
        "valueItems" in this.#options.getArgs()
          ? () => this.#options.getArgs().valueItems
          : undefined,
      resolveValue: this.#options.getArgs().resolveValue,
      resolveValues: this.#options.getArgs().resolveValues,
      getAllowCreate: () => this.#options.getArgs().allowCreate,
      createItem: this.#options.getArgs().createItem,
      createUnresolvedItem: this.#options.getArgs().createUnresolvedItem,
      specialItems: this.#options.getArgs().specialItems,
      groupBy: this.#options.getArgs().groupBy,
      groupDividers: this.#options.getArgs().groupDividers,
      groupHeader: this.#options.getArgs().groupHeader,
      groupFooter: this.#options.getArgs().groupFooter,
      onChange: this.handleChange,
      onReconfirm: (item, origin) => this.announcer.reconfirm(item, origin),
      onBulkUnchanged: (skipped) => this.announcer.bulkUnchanged(skipped),
      onUpdateStart: (isCurrent) => this.announcer.updateStarted(isCurrent),
      requestClose: () => this.#options.requestClose(),
      legacy: {
        owner: this.#options.owner,
        getElement: () => this.#options.getElement(),
        isDestroyed: () => isDestroying(this),
      },
    });
    this.feedback = new LoadFeedbackTracker({
      engine: this.engine,
      getFilterDebounceDelay: () =>
        this.#options.getPresenter().filterDebounceDelay,
      getSkeletonCountArg: () => this.#options.getArgs().skeletonCount,
    });

    this.listbox = new WindowedListCoordinator({
      engine: this.engine,
      feedback: this.feedback,
      onStillLoading: () => this.announcer.announceStillLoading(),
      getListboxId: () => this.#options.getListboxId(),
      isStaticModal: () => this.#options.isStaticModal(),
    });

    this.announcer = new SelectAnnouncer({
      a11y: this.#options.getA11y(),
      canReport: this.#options.canReport,
      engine: this.engine,
      getActiveOptionKey: () => this.listbox.activeOptionKey,
      reannounceActive: () => this.listbox.reannounceActive(),
      getNoResultsLabel: () => this.#options.getArgs().noResultsLabel,
      getShouldSuppressEntryCount: () =>
        this.#options.shouldSuppressEntryCount(),
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
    opts?: SelectLoadOptions
  ): SelectListContent | Promise<SelectListContent> {
    const rawItems = this.engine.loadItems(context, opts);
    const report = (content: SelectListContent): SelectListContent => {
      if (!isDestroying(this) && !opts?.signal?.aborted) {
        this.query = content.filter;
      }
      return content;
    };
    // Stamped at resolve time, not call time: an aborted-then-superseded load never reaches
    // here, so the query read on resolution is the one these rows were fetched for.
    if (rawItems instanceof Promise) {
      return rawItems.then((items) =>
        report(
          Object.freeze({
            rawItems: items,
            filter: this.engine.filter,
            query: this.engine.queryKey,
            context: this.engine.requestLoadContext,
          })
        )
      );
    }
    const content = Object.freeze({
      rawItems,
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
   * single batch, and any id that can't resolve becomes an `__unresolved` fallback chip
   * (never a hole). Normalizing to descriptors here (not in the template) means the chips
   * are built once per value change and stay referentially stable across re-renders.
   */
  @action
  resolveMulti(
    value: unknown,
    opts?: SelectLoadOptions
  ):
    | readonly SelectDescriptor[]
    | Promise<readonly SelectDescriptor[] | undefined>
    | undefined {
    const resolved = this.engine.resolveSelection(value as SelectValue, opts);
    if (resolved == null) {
      return undefined;
    }
    if (resolved instanceof Promise) {
      return resolved.then((items) =>
        items === undefined
          ? undefined
          : this.engine.describeItems(items as SelectItemModel[])
      );
    }
    return this.engine.describeItems(resolved as SelectItemModel[]);
  }

  /**
   * Resolves the single bound value to its one display item for the trigger
   * `DAsyncContent`. Narrows the engine's arity-union return to the single form; a `null`
   * value returns `undefined` (routed to `:empty`), while a held value that can't resolve
   * comes back as an `__unresolved` fallback item rather than `undefined`.
   */
  @action
  resolveSingle(
    value: unknown,
    opts?: SelectLoadOptions
  ): SelectItemModel | Promise<SelectItemModel> {
    return this.engine.resolveSelection(value as SelectValue, opts) as
      | SelectItemModel
      | Promise<SelectItemModel>;
  }

  @action
  handleChange(
    nextValue: SelectValue,
    payload: SelectItemModel | SelectItemModel[] | null,
    change: Parameters<NonNullable<SelectEngineOptions["onChange"]>>[2]
  ): void {
    // This must be read before forwarding because the parent applies nextValue synchronously.
    const oldValues = this.#options.getArgs().value;
    this.announcer.valueChanged(oldValues, nextValue, {
      ...change,
      onAddedWithQuery: () => {
        this.#options.clearQuery();
      },
    });
    this.#options.getArgs().onChange?.(nextValue, payload, change);
  }

  /** Consumes parsed pastes while keeping selection and query cleanup under one authority. */
  @action
  handlePaste(event: ClipboardEvent): void | Promise<void> {
    const args = this.#options.getArgs();
    if (this.#options.getPresenter().isLocked || !args.parsePaste) {
      return;
    }
    const session = this.#options.session();
    const query = this.engine.queryKey;
    const result = args.parsePaste(
      event.clipboardData?.getData("text/plain") ?? "",
      {
        filter: this.engine.filter,
        options: this.engine.resolvedOptions,
        value: this.engine.value,
      }
    );
    if (result == null) {
      return;
    }
    event.preventDefault();
    return this.engine.control.update((scope) => {
      const apply = (items: readonly SelectItemModel[] | null | undefined) => {
        if (items == null || !scope.current) {
          return;
        }
        scope.selectMany(items);
        // Middleware may synchronously replace the selection intent or edit the query.
        if (
          scope.current &&
          this.#options.session() === session &&
          this.engine.queryKey === query
        ) {
          this.announcer.suppressCount();
          this.#options.clearQuery();
        }
      };
      if (result instanceof Promise) {
        return result.then(apply);
      }
      apply(result);
    });
  }
}
