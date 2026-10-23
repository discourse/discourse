import type SelectEngine from "discourse/ui-kit/select/select-engine";

/** The selection surface reached by the previous key at the start of the input. */
export type SelectionNavigationTarget = "chips" | "strip" | undefined;

/** Handles empty-query removal and logical previous-key entry into the host's selection surface. */
export function handleFieldKeydown(
  event: KeyboardEvent,
  {
    engine,
    multiple,
    locked,
    navigateToSelection,
    clearActive,
  }: {
    /** The engine whose held values can be removed. */
    engine: SelectEngine;
    /** Whether Backspace removes the last value instead of clearing a single value. */
    multiple: boolean | undefined;
    /** Blocks removal and selection navigation. */
    locked: boolean;
    /** Clears virtual list focus when an editing key moves the caret. */
    clearActive?: () => void;
    /** Consumes the event on successful entry, including any preventDefault before focus. */
    navigateToSelection: (event: KeyboardEvent) => boolean;
  }
): boolean {
  const input = event.target as HTMLInputElement;

  if (
    !event.isComposing &&
    ["Home", "End", "ArrowLeft", "ArrowRight"].includes(event.key)
  ) {
    clearActive?.();
    if (
      !event.shiftKey &&
      !event.ctrlKey &&
      !event.metaKey &&
      !event.altKey &&
      (event.key === "Home" || event.key === "End")
    ) {
      const caret = event.key === "Home" ? 0 : input.value.length;
      input.setSelectionRange(caret, caret);
    }
  }
  const previousKey =
    getComputedStyle(input).direction === "rtl" ? "ArrowRight" : "ArrowLeft";

  // Clearability governs the visible clear control, not empty-query keyboard removal.
  if (!event.isComposing && input.value === "" && engine.hasValue && !locked) {
    if (multiple && event.key === "Backspace") {
      event.preventDefault();
      engine.deselectLast();
      return true;
    }
    if (!multiple && (event.key === "Backspace" || event.key === "Delete")) {
      event.preventDefault();
      engine.clear();
      return true;
    }
  }

  if (
    event.key === previousKey &&
    !event.isComposing &&
    input.selectionStart === 0 &&
    input.selectionEnd === 0 &&
    engine.hasValue &&
    !locked
  ) {
    return navigateToSelection(event);
  }
  return false;
}
