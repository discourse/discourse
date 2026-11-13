/**
 * Returns the select's interaction target at or within `scope`, if any.
 * DSelect falls back to its root when no trigger input exists.
 */
export function selectControl(scope: Element): HTMLElement | null {
  const select = scope.matches(".select-kit, .d-select")
    ? scope
    : scope.querySelector(".select-kit, .d-select");

  if (!select) {
    return null;
  }

  if (select.matches(".select-kit")) {
    // TODO (select-kit-replacement-cleanup): remove the legacy select-kit branch.
    return select.querySelector<HTMLElement>(".select-kit-header");
  }

  return (
    select.querySelector<HTMLInputElement>(".d-select__input") ??
    (select instanceof HTMLElement ? select : null)
  );
}
