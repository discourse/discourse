import type { MoveTarget } from "discourse/ui-kit/d-reorderable-list/types";

/**
 * How long after the last chord move the full announcement lands. Long enough
 * that a held key reads as one run rather than a stream of sentences, short
 * enough that a deliberate single press still speaks it as a single press.
 */
export const RUN_SETTLE_MS = 400;

/** The list's move menu, identified by the attribute float-kit stamps on it. */
export const MENU_IDENTIFIER = "reorderable-list-move";
export const MENU_CONTENT_SELECTOR = `[data-identifier="${MENU_IDENTIFIER}"]`;

/** The destination each accelerator chord asks for. */
export const CHORD_TARGETS: Record<string, MoveTarget | undefined> = {
  ArrowUp: "up",
  ArrowDown: "down",
  Home: "top",
  End: "bottom",
};
