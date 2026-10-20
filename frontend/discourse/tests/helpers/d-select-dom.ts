import { find } from "@ember/test-helpers";

/** Resolves a select's trigger and its linked, potentially portaled panel. */
export default class DSelectDOM {
  /** Selector or element description used in diagnostics. */
  readonly description: string;

  /** The trigger root, including when the supplied selector targets its input. */
  readonly root: HTMLElement;

  /** Accepts a trigger root or any element inside it. */
  constructor(selector: string | HTMLElement = ".d-select") {
    this.description =
      typeof selector === "string"
        ? selector
        : selector.outerHTML.split(">")[0] + ">";
    const element = typeof selector === "string" ? find(selector) : selector;
    const root = element?.closest<HTMLElement>(".d-select");
    if (!root) {
      throw new Error(`DSelect ${this.description} was not found`);
    }
    this.root = root;
  }

  /** Static selects use the trigger itself as their keyboard controller. */
  get controller(): HTMLElement {
    return this.filter ?? this.root;
  }

  /** Mobile and button variants keep their query input inside the panel. */
  get filter(): HTMLInputElement | null {
    return (
      this.root.querySelector<HTMLInputElement>(".d-select__input") ??
      this.panel?.querySelector<HTMLInputElement>(".d-select__filter") ??
      null
    );
  }

  /** Resolves the linked panel independently of whether it contains a listbox. */
  get panel(): HTMLElement | null {
    const id = this.root.dataset.selectId;
    return id
      ? this.root.ownerDocument.querySelector<HTMLElement>(
          `.d-select__panel[data-select-id="${CSS.escape(id)}"]`
        )
      : null;
  }

  /** Returns only options belonging to this select, excluding section headings. */
  options(panel: HTMLElement): HTMLElement[] {
    return Array.from(
      panel.querySelectorAll<HTMLElement>('[role="option"][data-value]')
    );
  }
}
