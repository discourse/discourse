import { bind } from "discourse/lib/decorators";
import { INPUT_DELAY } from "discourse/lib/environment";
import type { DRovingFocusEntry } from "discourse/ui-kit/modifiers/d-roving-focus";
import type { SelectPresentationOptions } from "discourse/ui-kit/select/-internals/engine/customizations";
import type SelectEngine from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";

/** Presentation contract shared by every options body. */
export interface OptionsPresenter {
  /** Delay only re-filtered loads. */
  debounceFor(previous: unknown, next: unknown): number;
  /** Delay before a changed filter loads. */
  readonly filterDebounceDelay: number;
  /** Whether source failures offer retry. */
  readonly retryable: boolean;
  /** Whether focus stays on the controller. */
  readonly usesActiveRoving: boolean;
  /** Cursor policy when the list mounts. */
  readonly entryFocus: DRovingFocusEntry;
  /** Whether activation is blocked. */
  readonly isLocked: boolean;
  /** Field used for fallback row labels. */
  readonly labelField: string;
  /** Identity that triggers cursor reconciliation. */
  rovingItemsKey(items: readonly unknown[]): unknown;
}

/** Live arguments common to select presentations. */
export interface SelectPresenterArgs extends SelectPresentationOptions {
  /** Field used for fallback labels. */
  labelField?: string;
  /** Locks editing while retaining focusability. */
  readonly?: boolean;
  /** Whether source failures offer retry. */
  retryable?: boolean;
  /** Delay for filter changes. */
  debounce?: boolean | number;
  /** Id of the caller's visible caption, which names the control instead of `label`. */
  labelledBy?: string;
}

/** The filter of a list load context, which `DAsyncContent` hands back untyped. */
function filterOf(context: unknown): string | undefined {
  return (context as { filter?: string } | undefined)?.filter;
}

/** Presentation shared by popup and inline selects. */
export default class SelectPresenterBase {
  #engine: SelectEngine;
  #getArgs: () => SelectPresenterArgs;

  constructor(options: {
    /** The headless selection engine. */
    engine: SelectEngine;
    /** Reads the hosting component's live arguments. */
    getArgs: () => SelectPresenterArgs;
  }) {
    this.#engine = options.engine;
    this.#getArgs = options.getArgs;
  }

  /** Whether the resolved disabled option prevents opening or mutation. */
  get isDisabled(): boolean {
    return this.#engine.resolvedOptions.disabled ?? false;
  }

  get isReadonly(): boolean {
    return this.#getArgs().readonly ?? false;
  }

  get isLocked(): boolean {
    return this.isDisabled || this.isReadonly;
  }

  /** A source error offers a retry action unless a consumer opts out. */
  get retryable(): boolean {
    return this.#getArgs().retryable ?? true;
  }

  /**
   * How long a filter change waits before the list asks the source, in milliseconds. Defaults to
   * the input delay for a server-backed source (`engine.isAsync`) whose loader last answered with
   * a promise, so a client source or a loader that answers synchronously never waits; a consumer
   * can force a delay with `true`/a number or disable it with `false`.
   */
  get filterDebounceDelay(): number {
    const debounce =
      this.#getArgs().debounce ??
      (this.#engine.isAsync && !this.#engine.answersSynchronously);
    return debounce === true ? INPUT_DELAY : debounce || 0;
  }

  /**
   * The built-in limit hint, or `undefined` when neither bound applies. At-max wins over
   * below-min so a `minimum > maximum` misconfiguration still reads sensibly. Rendered in the
   * panel's top zone (a sibling of the list, not inside it), so it never competes with the
   * footer or an error body for the same edge.
   */
  get limitMessage(): string | undefined {
    if (this.#engine.atMaximum) {
      return i18n("d_select.max_reached", { count: this.#engine.maximum });
    }
    if (this.#engine.belowMinimum) {
      return i18n("d_select.min_not_reached", {
        count: this.#engine.minimum,
      });
    }
    return undefined;
  }

  get labelField(): string {
    return this.#getArgs().labelField ?? "name";
  }

  /** The combobox/listbox's resolved accessible name, or a default. */
  /** Id of the caller's visible caption, when it names the control. */
  get labelledBy(): string | undefined {
    return this.#getArgs().labelledBy;
  }

  get ariaLabelText(): string {
    return this.#engine.resolvedOptions.label ?? i18n("d_select.label");
  }

  /** The resolved empty-selection text for a single trigger. */
  get placeholder(): string | undefined {
    return this.#engine.resolvedOptions.placeholder;
  }

  /**
   * The list debounce forwarded to `DAsyncContent`. Only a filter change waits: a reveal or a
   * reload keeps the query the reader is looking at, so it fetches at once.
   */
  @bind
  debounceFor(previous: unknown, next: unknown): number {
    return filterOf(previous) !== filterOf(next) ? this.filterDebounceDelay : 0;
  }
}
