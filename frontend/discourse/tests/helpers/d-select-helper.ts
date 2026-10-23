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
    if (!this.#dom.isList && this.#dom.panel) {
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

  /** Dispatches by the rendered selection model, never by whether the requested item exists. */
  async remove(value: unknown): Promise<void> {
    switch (this.element().dataset.selectionRemoval) {
      case "trigger-chips":
        return this.removeTriggerChip(value);
      case "panel-chips":
        return this.removePanelChip(value);
      case "strip":
        return this.removeStripItem(value);
      case "selected-rows":
        return this.removeSelectedRow(value);
      default:
        throw new Error(
          `DSelect ${this.#dom.description}: unknown selection removal model`
        );
    }
  }

  /** Removes an expected interactive trigger chip. */
  async removeTriggerChip(value: unknown): Promise<void> {
    await this.#removeChip(
      this.element(),
      ".d-select__chip",
      value,
      "trigger chip"
    );
  }

  /** Removes an expected chip from a searchable panel field. */
  async removePanelChip(value: unknown): Promise<void> {
    await this.open();
    await this.#removeChip(
      this.#dom.panel,
      ".d-select__chips.--field .d-select__chip",
      value,
      "panel field chip"
    );
  }

  /** Removes an expected chip from a retained selection strip. */
  async removeStripItem(value: unknown): Promise<void> {
    await this.open();
    await this.#removeChip(
      this.#dom.panel,
      ".d-select__strip-item",
      value,
      "strip item"
    );
  }

  /** Deselects a checked row in a desktop local static list. */
  async removeSelectedRow(value: unknown): Promise<void> {
    await this.open();
    const panel = this.#dom.panel;
    if (this.element().dataset.selectionRemoval !== "selected-rows") {
      throw new Error(
        `DSelect ${this.#dom.description}: selected-row removal requires a desktop local static list`
      );
    }
    const row =
      panel &&
      this.#dom
        .options(panel)
        .find(
          (option) =>
            option.dataset.value === String(value) &&
            option.getAttribute("aria-selected") === "true"
        );
    await click(this.#required(row, `selected row for ${String(value)}`));
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

  async #removeChip(
    root: HTMLElement | null,
    selector: string,
    value: unknown,
    kind: string
  ): Promise<void> {
    const chip = Array.from(
      root?.querySelectorAll<HTMLElement>(selector) ?? []
    ).find((element) => element.dataset.value === String(value));
    await click(
      this.#required(
        chip?.querySelector("button"),
        `${kind} for ${String(value)}`
      )
    );
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
