import type SelectEngine from "discourse/ui-kit/select/select-engine";

/** The selection surface reached by the previous key at the start of the input. */
export type SelectionNavigationTarget = "chips" | "strip" | undefined;

/** Handles empty-query removal and ArrowLeft entry into the host's selection surface. */
export function handleFieldKeydown(
  event: KeyboardEvent,
  {
    engine,
    multiple,
    locked,
    navigateToSelection,
  }: {
    /** The engine whose held values can be removed. */
    engine: SelectEngine;
    /** Whether Backspace removes the last value instead of clearing a single value. */
    multiple: boolean | undefined;
    /** Blocks removal and selection navigation. */
    locked: boolean;
    /** Consumes the event on successful entry, including any preventDefault before focus. */
    navigateToSelection: (event: KeyboardEvent) => boolean;
  }
): boolean {
  const input = event.target as HTMLInputElement;

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
    event.key === "ArrowLeft" &&
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
