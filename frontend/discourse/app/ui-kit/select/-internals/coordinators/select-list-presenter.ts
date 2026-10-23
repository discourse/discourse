import { bind } from "discourse/lib/decorators";
import type { DRovingFocusEntry } from "discourse/ui-kit/modifiers/d-roving-focus";
import SelectPresenterBase, {
  type OptionsPresenter,
  type SelectPresenterArgs,
} from "discourse/ui-kit/select/-internals/coordinators/select-presenter-base";
import type SelectEngine from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";

/** Presentation for a persistent, searchable multi-select. */
export default class SelectListPresenter
  extends SelectPresenterBase
  implements OptionsPresenter
{
  #canSeed: () => boolean;
  #engine: SelectEngine;

  constructor(options: {
    /** The headless selection engine. */
    engine: SelectEngine;
    /** Reads the hosting component's live arguments. */
    getArgs: () => SelectPresenterArgs;
    /** Whether focus, query and selection limits permit automatic entry. */
    canSeed: () => boolean;
  }) {
    super(options);
    this.#engine = options.engine;
    this.#canSeed = options.canSeed;
  }

  get usesActiveRoving(): boolean {
    return true;
  }

  get entryFocus(): DRovingFocusEntry {
    return this.#canSeed() ? "first" : "none";
  }

  /** The search placeholder, falling back to the shared panel default. */
  get searchPlaceholderText(): string {
    return this.placeholder ?? i18n("d_select.search_placeholder");
  }

  /** Reconciles when focus ownership or cap eligibility changes, as well as the query. */
  @bind
  rovingItemsKey(): string {
    return `${this.#engine.queryKey}:${this.#canSeed()}`;
  }
}
