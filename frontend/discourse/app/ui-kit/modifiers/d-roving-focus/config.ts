import type { DisabledItems } from "discourse/ui-kit/-internals/cursor/item-scope";
import type { Orientation } from "discourse/ui-kit/-internals/cursor/navigation";
import type {
  DRovingFocusArgs,
  DRovingFocusEntry,
  DRovingFocusStrategy,
} from "./types";

/**
 * {@link DRovingFocusArgs} with every default resolved, so no consumer of a configuration has to
 * re-decide what an omitted argument meant.
 */
export interface DRovingFocusConfig {
  focusStrategy: DRovingFocusStrategy;
  orientation: Orientation;
  itemSelector: string;
  onActivate: DRovingFocusArgs["onActivate"];
  onActiveChange: DRovingFocusArgs["onActiveChange"];
  onBoundary: DRovingFocusArgs["onBoundary"];
  logicalCount: number | undefined;
  onJump: DRovingFocusArgs["onJump"];
  onRegisterApi: DRovingFocusArgs["onRegisterApi"];
  wrap: boolean;
  tabStop: boolean;
  restoreLostFocus: boolean;
  activeClass: string | null;
  itemsKey: unknown;
  resetKey: unknown;
  controllerElement: HTMLElement | string | null | undefined;
  entryFocus: DRovingFocusEntry;
  fallbackSkipsMarked: boolean;
  disabledItems: DisabledItems;
  onCrossAxis: DRovingFocusArgs["onCrossAxis"];
  typeAhead: boolean;
}

/**
 * Resolves the named arguments into a configuration, reading every one of them so the modifier
 * re-runs when any changes.
 */
export function normalizeConfig(named: DRovingFocusArgs): DRovingFocusConfig {
  return {
    focusStrategy: named.focusStrategy ?? "roving-tabindex",
    orientation: named.orientation ?? "grid",
    itemSelector: named.itemSelector,
    onActivate: named.onActivate,
    onActiveChange: named.onActiveChange,
    onBoundary: named.onBoundary,
    logicalCount: named.logicalCount,
    onJump: named.onJump,
    onRegisterApi: named.onRegisterApi,
    wrap: named.wrap ?? false,
    tabStop: named.tabStop ?? true,
    restoreLostFocus: named.restoreLostFocus ?? true,
    activeClass: named.activeClass ?? null,
    // This read is load-bearing even though the value is never consulted: consuming the
    // tag is what makes a changed `itemsKey` re-run `modify()` and reconcile the cursor.
    itemsKey: named.itemsKey,
    resetKey: named.resetKey,
    controllerElement: named.controllerElement,
    entryFocus: named.entryFocus ?? "selected-or-first",
    fallbackSkipsMarked: named.fallbackSkipsMarked ?? false,
    disabledItems: named.disabledItems ?? "skip",
    onCrossAxis: named.onCrossAxis,
    typeAhead: named.typeAhead ?? false,
  };
}
