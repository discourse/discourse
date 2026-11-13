import type { FloatKitTrigger } from "discourse/float-kit/lib/constants";

/**
 * The float outlet that an open modal dialog around `trigger` provides: a direct child of the
 * `aria-modal` element marked `data-float-outlet`. Browsers leave everything outside an open
 * modal dialog out of the accessibility tree, so a float opened from inside one has to render
 * within it to be reachable.
 *
 * @returns The outlet, or `null` when the trigger is not inside a modal dialog that provides one.
 */
export function dialogFloatOutlet(
  trigger: FloatKitTrigger | undefined
): HTMLElement | null {
  if (!(trigger instanceof Element)) {
    return null;
  }

  return (
    trigger
      .closest("[aria-modal='true']")
      ?.querySelector<HTMLElement>(":scope > [data-float-outlet]") ?? null
  );
}
