import QUnit from "qunit";
import DSelectDOM from "discourse/tests/helpers/d-select-dom";

/** Checks DSelect's public DOM hooks without opening or otherwise changing it. */
export class DSelectAssertions {
  readonly context: Assert;
  #dom: DSelectDOM;

  /** Uses the caller's assertion context so each check records exactly one result. */
  constructor(selector: string | HTMLElement, context: Assert) {
    this.context = context;
    this.#dom = new DSelectDOM(selector);
  }

  /** Checks for a clear button inside this trigger. */
  hasClear(message?: string): void {
    this.context
      .dom(this.#dom.root.querySelector(".d-select__clear"))
      .exists(this.#message("has a clear button", message));
  }

  /** Checks an option's disabled state in the linked, open panel. */
  hasDisabledOption(value: unknown, message?: string): void {
    this.#option("value", value, message, "aria-disabled");
  }

  /** Reads the desktop typeahead input or the visible trigger label. */
  hasLabel(text: string, message?: string): void {
    const root = this.#dom.root;
    const input = root.querySelector<HTMLInputElement>(".d-select__input");
    const description = this.#message(`has label ${text}`, message);
    if (input) {
      this.context.dom(input).hasValue(text, description);
    } else {
      this.context
        .dom(
          root.querySelector(
            ".d-select__value, .d-select__presentation, .d-select__placeholder"
          ) ?? root
        )
        .hasText(text, description);
    }
  }

  /** Reads the held selection's names from the root hook. */
  hasName(name: string, message?: string): void {
    this.context
      .dom(this.#dom.root)
      .hasAttribute(
        "data-name",
        name,
        this.#message(`has name ${name}`, message)
      );
  }

  /** Absence checks still require an open panel. */
  hasNoOption(value: unknown, message?: string): void {
    this.#withPanel((panel) => {
      this.context
        .dom(this.#findOption(panel, "value", value))
        .doesNotExist(this.#message(`has no option ${String(value)}`, message));
    }, message);
  }

  /** An empty root value hook denotes no held selection. */
  hasNoSelection(message?: string): void {
    this.context
      .dom(this.#dom.root)
      .hasAttribute(
        "data-value",
        "",
        this.#message("has no selection", message)
      );
  }

  /** Finds an option by its literal value hook. */
  hasOption(value: unknown, message?: string): void {
    this.#option("value", value, message);
  }

  /** Finds an option by its literal name hook. */
  hasOptionName(name: string, message?: string): void {
    this.#option("name", name, message);
  }

  /** Compares the complete rendered option order, with expected values stringified. */
  hasOptions(values: readonly unknown[], message?: string): void {
    this.#withPanel((panel) => {
      this.context.deepEqual(
        this.#dom.options(panel).map((option) => option.dataset.value),
        values.map(String),
        this.#message("has options in order", message)
      );
    }, message);
  }

  /** Checks an option's selected state in the linked, open panel. */
  hasSelectedOption(value: unknown, message?: string): void {
    this.#option("value", value, message, "aria-selected");
  }

  /** Reads the held selection's stringified values from the root hook. */
  hasValue(value: unknown, message?: string): void {
    this.context
      .dom(this.#dom.root)
      .hasAttribute(
        "data-value",
        String(value),
        this.#message(`has value ${String(value)}`, message)
      );
  }

  /** An unmounted panel denotes a closed select. */
  isClosed(message?: string): void {
    this.context.pushResult({
      result: this.#dom.panel === null,
      actual: this.#dom.panel !== null,
      expected: false,
      message: this.#message("is closed", message),
    });
  }

  /** Supports native disabled inputs and control variants' disabled trigger state. */
  isDisabled(message?: string): void {
    const root = this.#dom.root;
    const disabled =
      root.classList.contains("--disabled") ||
      root.getAttribute("aria-disabled") === "true" ||
      root.querySelector<HTMLInputElement>(".d-select__input")?.disabled ===
        true;
    this.context.pushResult({
      result: disabled,
      actual: disabled,
      expected: true,
      message: this.#message("is disabled", message),
    });
  }

  /** A mounted linked panel denotes an open select, including empty states. */
  isOpen(message?: string): void {
    this.context.pushResult({
      result: this.#dom.panel !== null,
      actual: this.#dom.panel !== null,
      expected: true,
      message: this.#message("is open", message),
    });
  }

  /** Hook values are compared directly rather than interpolated into CSS selectors. */
  #findOption(
    panel: HTMLElement,
    hook: "value" | "name",
    value: unknown
  ): HTMLElement | null {
    return (
      this.#dom
        .options(panel)
        .find((option) => option.dataset[hook] === String(value)) ?? null
    );
  }

  /** Even caller-supplied messages retain the select's identity. */
  #message(check: string, message?: string): string {
    return `DSelect ${this.#dom.description}: ${message ?? check}`;
  }

  /** Shares existence and ARIA checks while preserving one result per public check. */
  #option(
    hook: "value" | "name",
    value: unknown,
    message?: string,
    attribute?: string
  ): void {
    this.#withPanel((panel) => {
      const option = this.#findOption(panel, hook, value);
      const assertion = this.context.dom(option);
      const description = this.#message(
        `has option ${hook} ${String(value)}${attribute ? ` with ${attribute}="true"` : ""}`,
        message
      );
      if (attribute) {
        assertion.hasAttribute(attribute, "true", description);
      } else {
        assertion.exists(description);
      }
    }, message);
  }

  /** Closed selects fail even negative option checks, without changing their state. */
  #withPanel(check: (panel: HTMLElement) => void, message?: string): void {
    const panel = this.#dom.panel;
    if (panel) {
      check(panel);
    } else {
      this.context.pushResult({
        result: false,
        actual: "closed",
        expected: "open",
        message: this.#message(
          `is closed; option checks require an open select${message ? `: ${message}` : ""}`
        ),
      });
    }
  }
}

declare global {
  interface Assert {
    /** Checks a select trigger, or the select containing the matched input. */
    dSelect(selector?: string | HTMLElement): DSelectAssertions;
  }
}

/** Installs the assertions on QUnit's shared assertion context. */
export function setupDSelectAssertions(): void {
  QUnit.assert.dSelect = function (
    selector: string | HTMLElement = ".d-select"
  ) {
    return new DSelectAssertions(selector, this);
  };
}
