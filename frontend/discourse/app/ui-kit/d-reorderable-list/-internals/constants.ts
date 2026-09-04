import type { MoveTarget } from "discourse/ui-kit/d-reorderable-list/types";

/**
 * How long after the last chord move the full announcement lands. Long enough
 * that a held key reads as one run rather than a stream of sentences, short
 * enough that a deliberate single press still speaks it as a single press.
 */
export const RUN_SETTLE_MS = 400;

/** A table create row spans every real column without measuring the table. */
export const TABLE_CREATE_COLSPAN = 1000;

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

/**
 * The accelerator each destination answers to, derived rather than restated so
 * a chord added above appears in the menu without a second table to keep in
 * step. A destination absent here has no accelerator, which is what the menu
 * reads to decide whether to advertise one.
 */
export const TARGET_CHORDS = Object.fromEntries(
  Object.entries(CHORD_TARGETS).map(([key, target]) => [target, key])
) as Partial<Record<MoveTarget, string>>;
