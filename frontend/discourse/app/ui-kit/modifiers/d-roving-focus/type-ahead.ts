import loadAccessibleName from "discourse/lib/load-accessible-name";

const COLLATOR = new Intl.Collator(undefined, {
  sensitivity: "base",
  usage: "search",
});
const LAPSE_MS = 1000;

export interface TypeAheadContext {
  enabled: boolean;
  editableController: boolean;
  logicalCount: number | undefined;
  items: () => HTMLElement[];
  currentIndex: (items: HTMLElement[]) => number;
  activate: (item: HTMLElement) => void;
  reannounce: () => void;
  warnWindowed: () => void;
}

export default class TypeAhead {
  #query = "";
  #queryAt = 0;
  #accessibleName: ((element: Element) => string) | null = null;
  #namerPending = false;
  #destroyed = false;
  #enabled = false;

  configure(enabled: boolean): void {
    this.#enabled = enabled;
    if (!enabled || this.#accessibleName || this.#namerPending) {
      return;
    }
    this.#namerPending = true;
    loadAccessibleName().then((namer) => {
      this.#namerPending = false;
      if (!this.#destroyed && this.#enabled) {
        this.#accessibleName = namer;
      }
    });
  }

  handle(event: KeyboardEvent, context: TypeAheadContext): boolean {
    this.#expire(event.timeStamp);
    if (!this.#claims(event, context)) {
      return false;
    }
    if (!this.#accessibleName) {
      return true;
    }
    const items = context.items();
    if (context.logicalCount != null && context.logicalCount > items.length) {
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

  destroy(): void {
    this.#destroyed = true;
  }

  #expire(now: number): void {
    if (this.#query && now - this.#queryAt > LAPSE_MS) {
      this.#query = "";
    }
  }

  #claims(event: KeyboardEvent, context: TypeAheadContext): boolean {
    if (!context.enabled || event.key.length !== 1) {
      return false;
    }
    if (event.metaKey || (event.ctrlKey && !event.altKey)) {
      return false;
    }
    if (context.editableController) {
      return false;
    }
    return event.key !== " " || this.#query !== "";
  }

  #find(
    items: HTMLElement[],
    query: string,
    from: number,
    offset: number
  ): HTMLElement | undefined {
    const start = (Math.max(from, 0) + offset) % items.length;
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
