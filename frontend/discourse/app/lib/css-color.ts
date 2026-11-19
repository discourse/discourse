export interface CSSColorOptions {
  /** Element whose custom properties are resolved. Defaults to `document.body`. */
  context?: HTMLElement;
}

/**
 * Reads theme CSS custom properties as concrete colors.
 *
 * Unlike `getComputedStyle().getPropertyValue()`, which returns the raw token
 * stream, this resolves each value through a real CSS `color` property so
 * functions like `light-dark()` and nested `var()` compute before canvas-based
 * consumers, which can't resolve them, receive the value (e.g. `rgb(31, 31, 31)`).
 *
 * Names that aren't set in `context` resolve to an empty string.
 */
export function getCSSColors<T extends string>(
  names: readonly T[],
  { context = document.body }: CSSColorOptions = {}
): Record<T, string> {
  const contextStyle = getComputedStyle(context);
  const probe = document.createElement("span");
  probe.style.display = "none";
  context.append(probe);
  const probeStyle = getComputedStyle(probe);

  const colors = {} as Record<T, string>;
  for (const name of names) {
    if (!contextStyle.getPropertyValue(name).trim()) {
      colors[name] = "";
      continue;
    }
    probe.style.color = `var(${name})`;
    colors[name] = probeStyle.color;
  }

  probe.remove();
  return colors;
}

/**
 * Reads a single theme CSS custom property as a concrete color.
 * Prefer {@link getCSSColors} when reading several at once.
 */
export function getCSSColor(name: string, options?: CSSColorOptions): string {
  return getCSSColors([name], options)[name];
}
