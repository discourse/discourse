import { registerDestructor } from "@ember/destroyable";
import Modifier from "ember-modifier";

function numericStyleValue(style, property) {
  return Number.parseFloat(style[property]) || 0;
}

function borderBoxAdjustment(element) {
  const style = getComputedStyle(element);

  if (style.boxSizing !== "border-box") {
    return 0;
  }

  return (
    numericStyleValue(style, "borderTopWidth") +
    numericStyleValue(style, "borderBottomWidth")
  );
}

function resizeTextarea(element, { manageOverflow }) {
  element.style.height = "auto";

  const height = Math.ceil(element.scrollHeight + borderBoxAdjustment(element));
  element.style.height = `${height}px`;

  if (manageOverflow) {
    const maxHeight = Number.parseFloat(getComputedStyle(element).maxHeight);

    element.style.overflowY =
      Number.isFinite(maxHeight) && element.scrollHeight > maxHeight
        ? "auto"
        : "hidden";
  }
}

export default class AutoResizeTextarea extends Modifier {
  #element;
  #focusHandler;
  #inputHandler;
  #manageOverflow = false;
  #placeholderObserver;
  #resizeFrame;
  #resizeHandler;

  constructor(owner, args) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.cleanup());
  }

  modify(
    element,
    _,
    {
      enabled = true,
      manageOverflow = false,
      observeFocus = false,
      observeInput = false,
      observePlaceholder = false,
      observeWindow = false,
      value,
    }
  ) {
    void value;

    if (this.#element !== element) {
      this.cleanup();
      this.#element = element;
    }

    this.#manageOverflow = manageOverflow;

    this.#updateWindowObserver(observeWindow && enabled);
    this.#updateFocusObserver(observeFocus && enabled);
    this.#updateInputObserver(observeInput && enabled);
    this.#updatePlaceholderObserver(observePlaceholder && enabled);

    if (enabled) {
      this.#scheduleResize(manageOverflow);
    } else {
      this.#cancelResize();
    }
  }

  cleanup() {
    this.#cancelResize();
    this.#placeholderObserver?.disconnect();
    this.#placeholderObserver = undefined;

    if (this.#focusHandler) {
      this.#element?.removeEventListener("focus", this.#focusHandler);
      this.#element?.removeEventListener("blur", this.#focusHandler);
      this.#focusHandler = undefined;
    }

    if (this.#inputHandler) {
      this.#element?.removeEventListener("input", this.#inputHandler);
      this.#inputHandler = undefined;
    }

    if (this.#resizeHandler) {
      window.removeEventListener("resize", this.#resizeHandler);
      this.#resizeHandler = undefined;
    }

    this.#manageOverflow = false;
    this.#element = undefined;
  }

  #cancelResize() {
    if (this.#resizeFrame !== undefined) {
      cancelAnimationFrame(this.#resizeFrame);
      this.#resizeFrame = undefined;
    }
  }

  #scheduleResize(manageOverflow) {
    if (!this.#element) {
      return;
    }

    this.#cancelResize();

    this.#resizeFrame = requestAnimationFrame(() => {
      this.#resizeFrame = undefined;

      if (!this.#element) {
        return;
      }

      resizeTextarea(this.#element, { manageOverflow });
    });
  }

  #updateFocusObserver(shouldObserve) {
    if (!shouldObserve) {
      if (this.#focusHandler) {
        this.#element?.removeEventListener("focus", this.#focusHandler);
        this.#element?.removeEventListener("blur", this.#focusHandler);
        this.#focusHandler = undefined;
      }

      return;
    }

    if (this.#focusHandler) {
      return;
    }

    this.#focusHandler = () => {
      this.#scheduleResize(this.#manageOverflow);
    };

    this.#element.addEventListener("focus", this.#focusHandler);
    this.#element.addEventListener("blur", this.#focusHandler);
  }

  #updateInputObserver(shouldObserve) {
    if (!shouldObserve) {
      if (this.#inputHandler) {
        this.#element?.removeEventListener("input", this.#inputHandler);
        this.#inputHandler = undefined;
      }

      return;
    }

    if (this.#inputHandler) {
      return;
    }

    this.#inputHandler = () => {
      this.#scheduleResize(this.#manageOverflow);
    };

    this.#element.addEventListener("input", this.#inputHandler);
  }

  #updatePlaceholderObserver(shouldObserve) {
    if (!shouldObserve) {
      this.#placeholderObserver?.disconnect();
      this.#placeholderObserver = undefined;
      return;
    }

    if (this.#placeholderObserver) {
      return;
    }

    this.#placeholderObserver = new MutationObserver((mutations) => {
      if (
        mutations.some(
          (mutation) =>
            mutation.type === "attributes" &&
            mutation.attributeName === "placeholder"
        )
      ) {
        this.#scheduleResize(this.#manageOverflow);
      }
    });

    this.#placeholderObserver.observe(this.#element, {
      attributes: true,
      attributeFilter: ["placeholder"],
    });
  }

  #updateWindowObserver(shouldObserve) {
    if (!shouldObserve) {
      if (this.#resizeHandler) {
        window.removeEventListener("resize", this.#resizeHandler);
        this.#resizeHandler = undefined;
      }

      return;
    }

    if (this.#resizeHandler) {
      return;
    }

    this.#resizeHandler = () => {
      this.#scheduleResize(this.#manageOverflow);
    };

    window.addEventListener("resize", this.#resizeHandler);
  }
}
