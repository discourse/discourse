import loadAccessibleName from "discourse/lib/load-accessible-name";

const COLLATOR = new Intl.Collator(undefined, {
  sensitivity: "base",
  usage: "search",
});
const LAPSE_MS = 1000;

/** Operations and state needed to resolve a type-ahead keypress. */
export interface TypeAheadContext {
  editableController: boolean;
  logicalCount: number | undefined;

  /** Returns the number of selector-matched items currently mounted. */
  mountedCount: () => number;
  items: () => HTMLElement[];
  currentIndex: (items: HTMLElement[]) => number;
  activate: (item: HTMLElement) => void;
  reannounce: () => void;
  warnWindowed: () => void;
}

/** Matches buffered printable input against item accessible names. */
export default class TypeAhead {
  #query = "";
  #queryAt = 0;
  #accessibleName: ((element: Element) => string) | null = null;
  #namerPending = false;
  #destroyed = false;
  #enabled = false;
  #loader: typeof loadAccessibleName;

  /** @param loader Loads the accessible-name implementation. */
  constructor(loader: typeof loadAccessibleName = loadAccessibleName) {
    this.#loader = loader;
  }

  /** Enables or disables matching and primes the accessible-name implementation. */
  configure(enabled: boolean): void {
    this.#enabled = enabled;
    this.#load();
  }

  /** Handles a claimed character and reports whether keyboard routing should stop. */
  handle(event: KeyboardEvent, context: TypeAheadContext): boolean {
    this.#expire(event.timeStamp);
    if (!this.#claims(event, context)) {
      return false;
    }
    if (!this.#accessibleName) {
      // A group that never reconfigures would otherwise stay dead after a failed load, so the
      // keystroke itself is the retry.
      this.#load();
      return true;
    }
    const items = context.items();
    // A partial window makes prefix search report a nearer mounted match while a truer one is
    // unmounted; compare against all mounted matches, not only the navigable subset.
    if (
      context.logicalCount != null &&
      context.logicalCount > context.mountedCount()
    ) {
      context.warnWindowed();
      return true;
    }
    const repeated =
      this.#query !== "" &&
      [...this.#query].every((char) => char === event.key);
    this.#query += event.key;
    this.#queryAt = event.timeStamp;
    if (!items.length) {
      return true;
    }
    const from = context.currentIndex(items);
    const search = repeated ? event.key : this.#query;
    const match = this.#find(items, search, from, search.length > 1 ? 0 : 1);
    if (!match) {
      return true;
    }
    event.preventDefault();
    if (from >= 0 && items[from] === match) {
      context.reannounce();
    } else {
      context.activate(match);
    }
    return true;
  }

  /** Prevents a pending name-loader result from reviving matching after teardown. */
  destroy(): void {
    this.#destroyed = true;
  }

  #load(): void {
    if (!this.#enabled || this.#accessibleName || this.#namerPending) {
      return;
    }
    this.#namerPending = true;
    this.#loader().then(
      (namer) => {
        this.#namerPending = false;
        if (!this.#destroyed && this.#enabled) {
          this.#accessibleName = namer;
        }
      },
      () => {
        this.#namerPending = false;
      }
    );
  }

  #expire(now: number): void {
    if (this.#query && now - this.#queryAt > LAPSE_MS) {
      this.#query = "";
    }
  }

  #claims(event: KeyboardEvent, context: TypeAheadContext): boolean {
    if (event.key.length !== 1) {
      return false;
    }
    // AltGr sets both Ctrl and Alt on ISO layouts, so only Ctrl without Alt is a shortcut.
    if (event.metaKey || (event.ctrlKey && !event.altKey)) {
      return false;
    }
    if (context.editableController) {
      return false;
    }
    // Space activates on an empty query and extends a non-empty one.
    return event.key !== " " || this.#query !== "";
  }

  /**
   * Finds the first prefix match at or after `from + offset`, wrapping once.
   *
   * @param items - The navigable items, in DOM order.
   * @param query - The buffer, or only the repeated character when cycling by initial.
   * @param from - The cursor position, or a negative value when there is no cursor.
   * @param offset - Whether to skip the item at the cursor.
   */
  #find(
    items: HTMLElement[],
    query: string,
    from: number,
    offset: number
  ): HTMLElement | undefined {
    const start = from < 0 ? 0 : (from + offset) % items.length;
    for (let step = 0; step < items.length; step++) {
      const candidate = items[(start + step) % items.length];
      const name = this.#accessibleName?.(candidate) ?? "";
      if (
        name.length >= query.length &&
        COLLATOR.compare(name.slice(0, query.length), query) === 0
      ) {
        return candidate;
      }
    }
    return undefined;
  }
}
