import type {
  DRovingFocusArgs,
  DRovingFocusDisabledItems,
  DRovingFocusEntry,
  DRovingFocusStrategy,
  Orientation,
} from "./types";

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
  disabledItems: DRovingFocusDisabledItems;
  onCrossAxis: DRovingFocusArgs["onCrossAxis"];
  typeAhead: boolean;
}

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
