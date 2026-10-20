import { click, fillIn, triggerKeyEvent } from "@ember/test-helpers";
import DSelectDOM from "discourse/tests/helpers/d-select-dom";

/** Drives a DSelect through its trigger, linked panel, and stable value hooks. */
export class DSelect {
  #dom: DSelectDOM;

  /** Accepts a selector or an element inside a select trigger. */
  constructor(selector: string | HTMLElement = ".d-select") {
    this.#dom = new DSelectDOM(selector);
  }

  /** Clears the held selection through the trigger's clear button. */
  async clear(): Promise<void> {
    await click(
      this.#required(
        this.element().querySelector(".d-select__clear"),
        "clear button"
      )
    );
  }

  /** Closes through the variant's keyboard controller; a closed select is a no-op. */
  async close(): Promise<void> {
    if (this.#dom.panel) {
      await triggerKeyEvent(this.#dom.controller, "keydown", "Escape");
    }
  }

  /** Returns the resolved trigger root. */
  element(): HTMLElement {
    return this.#dom.root;
  }

  /** Clicking the trigger root opens every variant; an open select is a no-op. */
  async open(): Promise<void> {
    if (!this.#dom.panel) {
      await click(this.element());
    }
  }

  /** Removes the chip matching the literal string form of the value. */
  async remove(value: unknown): Promise<void> {
    const chip = Array.from(
      this.element().querySelectorAll<HTMLElement>(".d-select__chip")
    ).find((element) => element.dataset.value === String(value));
    await click(
      this.#required(
        chip?.querySelector(".d-select__chip-remove"),
        `remove button for ${String(value)}`
      )
    );
  }

  /** Replaces the query, including a typeahead's resting selection label. */
  async search(text: string): Promise<void> {
    await this.open();
    await fillIn(this.#required(this.#dom.filter, "filter input"), text);
  }

  /** Selects an option by its stable value hook. */
  async select(value: unknown): Promise<void> {
    await this.#select("value", value);
  }

  /** Selects an option by logical index, excluding group headers. */
  async selectByIndex(index: number): Promise<void> {
    await this.#select("logicalIndex", index);
  }

  /** Selects an option by its stable name hook. */
  async selectByName(name: string): Promise<void> {
    await this.#select("name", name);
  }

  /** Gives failed actions a diagnostic naming the select and missing target. */
  #required(element: Element | null | undefined, target: string): Element {
    if (!element) {
      throw new Error(
        `DSelect ${this.#dom.description}: ${target} was not found`
      );
    }
    return element;
  }

  /** Compares hook values directly so punctuation never becomes selector syntax. */
  async #select(
    hook: "value" | "name" | "logicalIndex",
    value: unknown
  ): Promise<void> {
    await this.open();
    const panel = this.#dom.panel;
    const option =
      panel &&
      this.#dom
        .options(panel)
        .find((element) => element.dataset[hook] === String(value));
    await click(this.#required(option, `option with ${hook} ${String(value)}`));
  }
}

/** Builds a driver for a select trigger or its inner input. */
export default function dSelect(
  selector: string | HTMLElement = ".d-select"
): DSelect {
  return new DSelect(selector);
}
