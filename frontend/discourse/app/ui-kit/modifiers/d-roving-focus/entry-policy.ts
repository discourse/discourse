import type { DRovingFocusConfig } from "./config";

function hasCurrentToken(item: HTMLElement): boolean {
  const current = item.getAttribute("aria-current");
  return current !== null && current !== "" && current !== "false";
}

/** Returns whether entry should prefer a marked item. */
export function prefersSelected(config: DRovingFocusConfig): boolean {
  return (
    config.entryFocus === "selected-or-first" ||
    config.entryFocus === "selected-or-none"
  );
}

/** Returns whether entry may fall back to the first eligible item. */
export function fallsBackToFirst(config: DRovingFocusConfig): boolean {
  return (
    config.entryFocus === "first" || config.entryFocus === "selected-or-first"
  );
}

/** Returns whether an item carries any supported chosen-value marker. */
export function isMarked(item: HTMLElement): boolean {
  return (
    item.getAttribute("aria-selected") === "true" ||
    item.getAttribute("aria-checked") === "true" ||
    hasCurrentToken(item)
  );
}

/**
 * Finds the highest-priority eligible marker, searching by attribute before document order so
 * explicit selection consistently outranks a merely current item.
 */
export function findMarked(
  items: HTMLElement[],
  eligible: (item: HTMLElement) => boolean = () => true
): HTMLElement | undefined {
  return (
    items.find(
      (item) => item.getAttribute("aria-selected") === "true" && eligible(item)
    ) ??
    items.find(
      (item) => item.getAttribute("aria-checked") === "true" && eligible(item)
    ) ??
    items.find((item) => hasCurrentToken(item) && eligible(item))
  );
}

/** Chooses the active-descendant entry target under the configured fallback policy. */
export function activeSeed(
  items: HTMLElement[],
  config: DRovingFocusConfig
): HTMLElement | undefined {
  const selected = prefersSelected(config) ? findMarked(items) : undefined;
  if (selected || !fallsBackToFirst(config)) {
    return selected;
  }
  return config.fallbackSkipsMarked
    ? items.find((item) => !isMarked(item))
    : items[0];
}
