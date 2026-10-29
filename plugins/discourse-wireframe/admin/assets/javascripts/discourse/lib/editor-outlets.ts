/** The outlet whose layout the homepage opt-in publishes as `/`. */
export const HOMEPAGE_OUTLET = "homepage-blocks";

/**
 * The block outlets the editor exposes for editing. Every other outlet on the
 * page renders exactly as it does live: no boundary, chrome, drop target,
 * outline or issues row, and no session draft.
 *
 * Deliberately narrow for now while the editing experience is shaped around the
 * homepage. Widening it is a change here only; the rest of the editor already
 * handles any registered outlet.
 */
export const EDITOR_OUTLETS: ReadonlySet<string> = new Set([HOMEPAGE_OUTLET]);

/**
 * Whether the editor exposes an outlet for editing.
 *
 * @param outletName - Registry-level outlet name to check.
 */
export function isEditorOutlet(outletName: string | null | undefined): boolean {
  return outletName != null && EDITOR_OUTLETS.has(outletName);
}
